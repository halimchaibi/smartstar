package com.smartstar.ingestion.streaming

import com.smartstar.common.config.{AppConfig, Environment}
import com.smartstar.common.traits.{ConfigurableJob, EnvironmentAwareSparkJob}
import org.apache.spark.sql.DataFrame
import org.apache.spark.sql.functions._
//import org.apache.spark.sql.streaming.Trigger

class KafkaStreamingJob extends EnvironmentAwareSparkJob with ConfigurableJob  {
  
  override def appName: String = "SmartStar-Kafka-Streaming"
  override def config: AppConfig = AppConfig.load()

  private val checkpointLocation: String = s"/tmp/checkpoints/${environment.name}/$appName"

  // Customize configurations per job
  override def additionalSparkConfigs: Map[String, String] = Map(
    "spark.sql.sources.parallelPartitionDiscovery.threshold" -> "32",
    "spark.sql.files.maxPartitionBytes" -> "134217728" // 128MB
  )

  override def run(args: Array[String]): Unit = {
    validateConfig()

    logInfo(s"Running in environment: ${config.environment}")
    logInfo(s"Module: ${config.module.getOrElse("unknown")}")

    // Access any configuration value via rawConfig
//    val customSetting = config.rawConfig.getString("custom.setting")
//    val optionalSetting = if (config.rawConfig.hasPath("optional.setting")) {
//      Some(config.rawConfig.getString("optional.setting"))
//    } else {
//      None
//    }

    // Access structured configuration
    logInfo(s"Database host: ${config.databaseConfig.host}")
    logInfo(s"Kafka servers: ${config.kafkaConfig.bootstrapServers}")
    logInfo(s"Storage path: ${config.storageConfig.basePath}")

    // Access Spark-specific configuration
    logInfo(s"Spark master: ${config.sparkConfig.master}")
    logInfo(s"Executor memory: ${config.sparkConfig.executorMemory}")


    val outputPath = args.lift(1).getOrElse(
      s"${config.storageConfig.basePath}/ingestion/output"
    )
    
    // Parse arguments
    val topic = args.headOption.getOrElse("smartstar-events")
    
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
    val topics = getString("kafka.topics")

    spark.readStream
        .format("kafka")
        .option("kafka.bootstrap.servers", getKafkaBootstrapServers)
        .option("subscribe", topics)
        .option("startingOffsets", "latest")
        .load()
  }
  
  private def processStream(df: DataFrame): DataFrame = {
    logInfo("Processing Kafka stream")

    val bronzeRaw = df.selectExpr("CAST(value AS STRING) as value", "topic", "partition", "offset", "timestamp")
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
  
  private def writeStream(df: DataFrame, outputPath: String, checkpointLocation: String) = {
    logInfo(s"Writing stream to $outputPath")

    val bronzeBasePath = getString("ingestion.bronze.base.path")
    val checkpointBase = getString("ingestion.checkpoint.base.path")

    df.writeStream
        .format("json")
        .option("path", bronzeBasePath)
        .option("checkpointLocation", checkpointBase)
        .partitionBy("topic", "year", "month", "day")
        .outputMode("append")
        .start()
  }

  private def getString(path: String): String = config.rawConfig.getString(path)

  private def getKafkaBootstrapServers: String = {
    environment match {
      case Environment.Development => "localhost:9092"
      case Environment.Staging => "kafka-staging:9092"
      case Environment.Production => "kafka-prod:9092"
      case Environment.Test => "localhost:9092"
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

  object ConfigDebug {

    def printConfig(config: AppConfig): Unit = {
      println("=== AppConfig Debug ===")
      println(s"App Name: ${config.appName}")
      println(s"Version: ${config.version}")
      println(s"Environment: ${config.environment}")
      println(s"Module: ${config.module}")
      println()

      println("=== Spark Config ===")
      println(s"Master: ${config.sparkConfig.master}")
      println(s"App Name: ${config.sparkConfig.appName}")
      println(s"Executor Memory: ${config.sparkConfig.executorMemory}")
      println(s"Executor Cores: ${config.sparkConfig.executorCores}")
      println(s"Driver Memory: ${config.sparkConfig.driverMemory}")
      println()

      println("=== Database Config ===")
      println(s"Host: ${config.databaseConfig.host}")
      println(s"Port: ${config.databaseConfig.port}")
      println(s"Database: ${config.databaseConfig.name}")
      println(s"Username: ${config.databaseConfig.username}")
      println(s"SSL: ${config.databaseConfig.ssl}")
      println()

      println("=== Storage Config ===")
      println(s"Base Path: ${config.storageConfig.basePath}")
      println(s"Checkpoint Location: ${config.storageConfig.checkpointLocation}")
      println(s"Input Format: ${config.storageConfig.inputFormat}")
      println(s"Output Format: ${config.storageConfig.outputFormat}")
      println()
    }

    def printRawConfig(config: AppConfig): Unit = {
      import com.typesafe.config.ConfigRenderOptions

      val options = ConfigRenderOptions.defaults()
        .setComments(false)
        .setOriginComments(false)
        .setFormatted(true)
        .setJson(false)

      println("=== Raw Configuration ===")
      println(config.rawConfig.root().render(options))
      println("========================")
    }

    def validatePaths(config: AppConfig): Unit = {
      val requiredPaths = Seq(
        "app.name",
        "app.version",
        "environment",
        "spark.master",
        "spark.executor.memory",
        "database.host",
        "kafka.bootstrap-servers",
        "storage.base-path"
      )

      println("=== Configuration Path Validation ===")
      requiredPaths.foreach { path =>
        if (config.rawConfig.hasPath(path)) {
          val value = config.rawConfig.getString(path)
          println(s"✅ $path = $value")
        } else {
          println(s"❌ $path = MISSING")
        }
      }
      println("===================================")
    }
  }
}

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