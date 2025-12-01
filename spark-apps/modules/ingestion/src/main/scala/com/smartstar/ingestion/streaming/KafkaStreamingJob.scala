package com.smartstar.ingestion.streaming

import com.smartstar.common.config.{AppConfig, ConfigurationFactory}
import com.smartstar.common.traits.{ConfigurableJob, Environment, EnvironmentAwareSparkJob, Module}
import org.apache.spark.sql.DataFrame
import org.apache.spark.sql.functions._

class KafkaStreamingJob extends EnvironmentAwareSparkJob with ConfigurableJob {

  override def appName: String = s"${config.appName}-KafkaStreamingJob"


  override def config: AppConfig =
    ConfigurationFactory.forEnvironmentAndModule(Environment.detect(), Module.Ingestion)


  // Customize configurations per job
  override def additionalSparkConfigs: Map[String, String] = Map(
    "spark.sql.sources.parallelPartitionDiscovery.threshold" -> "32",
    "spark.sql.files.maxPartitionBytes" -> "134217728" // 128MB
  )

  override def run(args: Array[String]): Unit = {

    validateConfig()

    logInfo(s"Running in environment: ${config.environment.name}")
    logInfo(s"Module: ${config.module.name}")
    // Access Spark-specific configuration
    logInfo(s"Spark master: ${config.rawConfig.getString("spark.master")}")
    logInfo(s"Executor memory: ${config.rawConfig.getString("spark.executor.memory")}")

    // Read from Kafka
    val kafkaDF = readFromKafka()

    // Process stream
    val processedDF = processStream(kafkaDF)

    // Write stream
    val query = writeStream(processedDF)

    // Wait for termination
    query.awaitTermination()
  }

  private def readFromKafka(): DataFrame = {
    val topics = getString("kafka.topics")
    val kafkaBootstrapServers = getString("kafka.bootstrap-servers")
    val startingOffsets = scala.util.Try(getString("kafka.starting-offsets")).getOrElse("earliest")
    
    logInfo(s"Reading from Kafka topic: $topics")
    logInfo(s"Kafka bootstrap servers: $kafkaBootstrapServers")
    logInfo(s"Starting offsets: $startingOffsets")

    spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", kafkaBootstrapServers)
      .option("subscribe", topics)
      .option("startingOffsets", startingOffsets)
      .option("failOnDataLoss", "false")
      .load()
  }

  private def processStream(df: DataFrame): DataFrame = {
    logInfo("Processing Kafka stream")

    val bronzeRaw = df
      .selectExpr("CAST(value AS STRING) as value", "topic", "partition", "offset", "timestamp")
      .withColumn("topic", col("topic"))
      .withColumn("partition", col("partition"))
      .withColumn("offset", col("offset"))
      .withColumn("kafka_timestamp", col("timestamp"))
      .withColumn("ingestion_ts", current_timestamp())

    bronzeRaw
      .withColumn("event_time", to_timestamp(get_json_object(col("value"), "$.timestamp")))
      .withColumn("year", year(col("event_time")))
      .withColumn("month", month(col("event_time")))
      .withColumn("day", dayofmonth(col("event_time")))
  }

  private def writeStream(df: DataFrame) = {

    val output = getString("storage.datalake.output")
    val checkpoint = getString("kafka.checkpoint-location")
    logInfo(s"Writing stream to $output")

    df.writeStream
      .format("json")
      .option("path", output)
      .option("checkpointLocation", checkpoint)
      .partitionBy("topic", "year", "month", "day")
      .outputMode("append")
      .start()
  }

  private def getString(path: String): String = config.rawConfig getString path

}

object KafkaStreamingJob {
  def main(args: Array[String]): Unit = {
    val job = new KafkaStreamingJob()
    try {
      job.run(args)
    } finally {
      // Close resources and stop Spark session
      try {
        job.close()
      } catch {
        case ex: Exception =>
          println(s"Warning: Error while closing job resources: ${ex.getMessage}")
      }
    }
  }
}
