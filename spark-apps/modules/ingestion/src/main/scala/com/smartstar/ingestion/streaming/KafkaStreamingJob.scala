package com.smartstar.ingestion.streaming

import com.smartstar.common.config.{AppConfig, ConfigurationFactory}
import com.smartstar.common.traits.{ConfigurableJob, Environment, EnvironmentAwareSparkJob, Module}
import org.apache.spark.sql.DataFrame
import org.apache.spark.sql.functions._
//import org.apache.spark.sql.streaming.Trigger

class KafkaStreamingJob extends EnvironmentAwareSparkJob with ConfigurableJob {

  override def appName: String = "SmartStar-Kafka-Streaming"
  override def config: AppConfig =
    ConfigurationFactory.forEnvironmentAndModule(Environment.Development, Module.Ingestion)

  // Customize configurations per job
  override def additionalSparkConfigs: Map[String, String] = Map(
    "spark.sql.sources.parallelPartitionDiscovery.threshold" -> "32",
    "spark.sql.files.maxPartitionBytes" -> "134217728" // 128MB
  )

  override def run(args: Array[String]): Unit = {

    validateConfig()

    logInfo(s"Running in environment: ${config.environment}")
    logInfo(s"Module: ${config.module}")
    // Access Spark-specific configuration
    logInfo(s"Spark master: ${config.sparkConfig.master}")
    logInfo(s"Executor memory: ${config.sparkConfig.executorMemory}")

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
    val topics = getString("kafka.topics.input")
    val kafkaBootstrapServers = getString(s"kafka.bootstrap-servers")

    logInfo(s"Reading from Kafka topic: $topics")

    spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", kafkaBootstrapServers)
      .option("subscribe", topics)
      .option("startingOffsets", "latest")
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

    val bronzeBasePath = getString("ingestion.bronze.base.path")
    val checkpointBase = getString("ingestion.checkpoint.base.path")
    logInfo(s"Writing stream to $checkpointBase")

    df.writeStream
      .format("json")
      .option("path", bronzeBasePath)
      .option("checkpointLocation", checkpointBase)
      .partitionBy("topic", "year", "month", "day")
      .outputMode("append")
      .start()
  }

  private def getString(path: String): String = config.rawConfig.getString(path)
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

//  object ConfigDebug {
//
//    def printConfig(config: AppConfig): Unit = {
//      println("=== AppConfig Debug ===")
//      println(s"App Name: ${config.appName}")
//      println(s"Version: ${config.version}")
//      println(s"Environment: ${config.environment}")
//      println(s"Module: ${config.module}")
//      println()
//
//      println("=== Spark Config ===")
//      println(s"Master: ${config.sparkConfig.master}")
//      println(s"App Name: ${config.sparkConfig.appName}")
//      println(s"Executor Memory: ${config.sparkConfig.executorMemory}")
//      println(s"Executor Cores: ${config.sparkConfig.executorCores}")
//      println(s"Driver Memory: ${config.sparkConfig.driverMemory}")
//      println()
//
//      println("=== Database Config ===")
//      println(s"Host: ${config.databaseConfig.host}")
//      println(s"Port: ${config.databaseConfig.port}")
//      println(s"Database: ${config.databaseConfig.name}")
//      println(s"Username: ${config.databaseConfig.username}")
//      println(s"SSL: ${config.databaseConfig.ssl}")
//      println()
//
//      println("=== Storage Config ===")
//      println(s"Base Path: ${config.storageConfig.basePath}")
//      println(s"Checkpoint Location: ${config.storageConfig.checkpointLocation}")
//      println(s"Input Format: ${config.storageConfig.inputFormat}")
//      println(s"Output Format: ${config.storageConfig.outputFormat}")
//      println()
//    }
//
//    def printRawConfig(config: AppConfig): Unit = {
//      import com.typesafe.config.ConfigRenderOptions
//
//      val options = ConfigRenderOptions.defaults()
//        .setComments(false)
//        .setOriginComments(false)
//        .setFormatted(true)
//        .setJson(false)
//
//      println("=== Raw Configuration ===")
//      println(config.rawConfig.root().render(options))
//      println("========================")
//    }
//
//    def validatePaths(config: AppConfig): Unit = {
//      val requiredPaths = Seq(
//        "app.name",
//        "app.version",
//        "environment",
//        "spark.master",
//        "spark.executor.memory",
//        "database.host",
//        "kafka.bootstrap-servers",
//        "storage.base-path"
//      )
//
//      println("=== Configuration Path Validation ===")
//      requiredPaths.foreach { path =>
//        if (config.rawConfig.hasPath(path)) {
//          val value = config.rawConfig.getString(path)
//          println(s"✅ $path = $value")
//        } else {
//          println(s"❌ $path = MISSING")
//        }
//      }
//      println("===================================")
//    }
//  }
//}

// ===== QUICK TEST =====

/*
object ConfigTest extends App {

  // Set environment for testing
  System.setProperty("SPARK_ENV", "development")
  System.setProperty("MODULE_NAME", "ingestion")

  try {
    val config = AppConfig.load()

    println("✅ Configuration loaded successfully!")
    ConfigDebug.printConfig(config)
    ConfigDebug.validatePaths(config)

    // Test rawConfig access
    println("\n=== Raw Config Test ===")
    println(s"Custom value: ${config.rawConfig.getString("app.name")}")

  } catch {
    case ex: Exception =>
      println(s"❌ Configuration loading failed: ${ex.getMessage}")
      ex.printStackTrace()
  }

 */
