package com.smartstar.normalization.streaming

import com.smartstar.common.config.{AppConfig, ConfigurationFactory}
import com.smartstar.common.traits.Environment.{Development, Test, detect}
import com.smartstar.common.traits.Module.Normalization
import com.smartstar.common.traits.{ConfigurableJob, EnvironmentAwareSparkJob}
import org.apache.spark.sql.{DataFrame, SparkSession}
import org.apache.spark.sql.functions._
import org.apache.spark.sql.types._

class S3StreamingJob extends EnvironmentAwareSparkJob with ConfigurableJob {

  override def appName: String = s"${config.appName}-SensorSilverStreaming"

  override def config: AppConfig = ConfigurationFactory.forEnvironmentAndModule(detect(), Normalization)

  override def additionalSparkConfigs: Map[String, String] = Map(
    "spark.sql.catalog.sensors" -> "org.apache.iceberg.spark.SparkCatalog"
  )

  private val rawSchema = StructType(Seq(
    StructField("event_time", StringType, nullable = true),
    StructField("ingestion_ts", StringType, nullable = true),
    StructField("kafka_timestamp", StringType, nullable = true),
    StructField("offset", LongType, nullable = true),
    StructField("partition", LongType, nullable = true),
    StructField("timestamp", StringType, nullable = true),
    StructField("value", StringType, nullable = true),
    StructField("year", IntegerType, nullable = true),
    StructField("month", IntegerType, nullable = true),
    StructField("day", IntegerType, nullable = true)
  ))

  private val payloadSchema = StructType(Seq(
    StructField("device_id", StringType, nullable = true),
    StructField("timestamp", StringType, nullable = true),
    StructField("sensor_type", StringType, nullable = true),
    StructField("location", StructType(Seq(
      StructField("latitude", DoubleType, nullable = true),
      StructField("longitude", DoubleType, nullable = true),
      StructField("city", StringType, nullable = true)
    )), nullable = true),
    StructField("temperature", DoubleType, nullable = true),
    StructField("humidity", DoubleType, nullable = true),
    StructField("unit", StringType, nullable = true)
  ))

  override def run(args: Array[String]): Unit = {
    try {
      logInfo(s"Starting Spark job for $appName")

      initializeIcebergTable()
      val rawStream= streamFromS3()

        val decodedStream = decodeRawStream(rawStream)
        val transformedStream = transformStreamData(decodedStream)
        writeStreamToIceberg(transformedStream)
    } catch {
      case e: Exception =>
        logError(s"Uncaught exception in Spark job for $appName", e)
        throw e
    } finally {
      close()
    }
  }

  private def initializeIcebergTable(): Unit = {
    logInfo("Initializing Iceberg table")
    spark.sql(
      """
        |CREATE TABLE IF NOT EXISTS sensors.silver_dev.temperature (
        |  device_id STRING,
        |  device_ts TIMESTAMP,
        |  sensor_type STRING,
        |  latitude DOUBLE,
        |  longitude DOUBLE,
        |  city STRING,
        |  temperature DOUBLE,
        |  humidity DOUBLE,
        |  unit STRING,
        |  event_time TIMESTAMP,
        |  year INT,
        |  month INT,
        |  day INT
        |)
        |USING iceberg
        |PARTITIONED BY (year, month, day)
        |""".stripMargin)
  }

  private def streamFromS3(): DataFrame = {
    val inputPath = getValue("streaming.input")
    
    logInfo(s"Reading from: $inputPath")

    spark.readStream
      .format("json")
      .schema(rawSchema)
      .option("maxFilesPerTrigger", 10)
      .option("pathGlobFilter", "*.json")
      .option("columnNameOfCorruptRecord", "_corrupt_record")
      .option("mode", "PERMISSIVE")
      .load(inputPath)
  }

  private def writeStreamToIceberg(transformedStream: DataFrame): Unit = {
    val checkpointPath = getValue("streaming.checkpoint-location")
    val query = transformedStream.writeStream
      .format("iceberg")
      .outputMode("append")
      .option("checkpointLocation", checkpointPath)
      .toTable("sensors.temperature")

    query.awaitTermination()
  }

  private def decodeRawStream(rawStream: DataFrame): DataFrame = {
    rawStream
      .withColumn("data", from_json(col("value"), payloadSchema))
      .select(
        col("partition"),
        col("offset"),
        col("timestamp"),
        col("event_time"),
        col("data.device_id"),
        col("data.timestamp").alias("device_ts"),
        col("data.sensor_type"),
        col("data.location.latitude"),
        col("data.location.longitude"),
        col("data.location.city"),
        col("data.temperature"),
        col("data.humidity"),
        col("data.unit"),
        col("year"),
        col("month"),
        col("day")
      )
  }

  private def transformStreamData(decodedStream: DataFrame): DataFrame = {
  decodedStream
    .select(
      col("device_id"),
      col("device_ts"),
      col("sensor_type"),
      col("latitude"),
      col("longitude"),
      col("city"),
      col("temperature"),
      col("humidity"),
      col("unit"),
      col("event_time"),
      col("year"),
      col("month"),
      col("day")
    )
    .withColumn("device_ts", to_timestamp(col("device_ts")))
    .withColumn("event_time", to_timestamp(col("event_time")))
  }

  private def getValue(key: String): String = {
    val value = config.rawConfig.getString(key)
    if (value == null) {
      throw new IllegalArgumentException(s"Missing configuration value for key: $key")
    }
    value
  }
}

object S3StreamingJob {
  def main(args: Array[String]): Unit = {
    val job = new S3StreamingJob()
    try {
      job.run(args)
    } finally {
      try {
        job.close()
      } catch {
        case ex: Exception =>
          println(s"Warning: Error while closing job resources: ${ex.getMessage}")
      }
    }
  }
}