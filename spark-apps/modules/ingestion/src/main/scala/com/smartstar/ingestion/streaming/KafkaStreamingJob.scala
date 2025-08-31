package com.smartstar.ingestion.streaming

import com.smartstar.common.traits.{SparkJob, ConfigurableJob}
import com.smartstar.common.config.AppConfig
import org.apache.spark.sql.{DataFrame, SparkSession}
import org.apache.spark.sql.streaming.Trigger
import org.apache.spark.sql.functions._

class KafkaStreamingJob extends SparkJob with ConfigurableJob {
  
  override def appName: String = "SmartStar-Kafka-Streaming"
  override def config: AppConfig = AppConfig.load()
  
  override def run(args: Array[String]): Unit = {
    validateConfig()
    
    logInfo(s"Starting $appName")
    
    // Parse arguments
    val topic = args.headOption.getOrElse("smartstar-events")
    val outputPath = args.lift(1).getOrElse("data/streaming-output/")
    val checkpointLocation = args.lift(2).getOrElse("/tmp/kafka-checkpoint")
    
    // Read from Kafka
    val kafkaDF = readFromKafka(topic)
    
    // Process stream
    val processedDF = processStream(kafkaDF)
    
    // Write stream
    val query = writeStream(processedDF, outputPath, checkpointLocation)
    
    // Wait for termination
    query.awaitTermination()
  }
  
  private def readFromKafka(topic: String): DataFrame = {
    logInfo(s"Reading from Kafka topic: $topic")
    
    spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", "localhost:9092")
      .option("subscribe", topic)
      .option("startingOffsets", "latest")
      .load()
  }
  
  private def processStream(df: DataFrame): DataFrame = {
    logInfo("Processing Kafka stream")
    
    df.selectExpr("CAST(key AS STRING)", "CAST(value AS STRING)", "timestamp")
      .withColumn("processed_at", current_timestamp())
      .withColumn("date_partition", date_format(col("timestamp"), "yyyy-MM-dd"))
  }
  
  private def writeStream(df: DataFrame, outputPath: String, checkpointLocation: String) = {
    logInfo(s"Writing stream to $outputPath")
    
    df.writeStream
      .outputMode("append")
      .format("parquet")
      .option("path", outputPath)
      .option("checkpointLocation", checkpointLocation)
      .partitionBy("date_partition")
      .trigger(Trigger.ProcessingTime("30 seconds"))
      .start()
  }
}

object KafkaStreamingJob {
  def main(args: Array[String]): Unit = {
    val job = new KafkaStreamingJob()
    try {
      job.run(args)
    } finally {
      job.close()
    }
  }
}
