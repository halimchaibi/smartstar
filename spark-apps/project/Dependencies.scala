import sbt._

object Dependencies {
  
  object Versions {
    val spark = "3.5.0"
    val scala = "2.13.11"
    val scalaTest = "3.2.16"
    val typesafeConfig = "1.4.2"
    val slf4j = "2.0.7"
    val logback = "1.4.8"
    val kafka = "3.5.1"
    val aws = "1.12.499"
    val delta = "2.4.0"
  }
  
  // Spark dependencies
  val sparkCore = "org.apache.spark" %% "spark-core" % Versions.spark % "provided"
  val sparkSql = "org.apache.spark" %% "spark-sql" % Versions.spark % "provided"
  val sparkStreaming = "org.apache.spark" %% "spark-streaming" % Versions.spark % "provided"
  val sparkMllib = "org.apache.spark" %% "spark-mllib" % Versions.spark % "provided"
  val sparkAvro = "org.apache.spark" %% "spark-avro" % Versions.spark % "provided"
  val sparkKafka = "org.apache.spark" %% "spark-streaming-kafka-0-10" % Versions.spark % "provided"
  
  // Configuration
  val typesafeConfig = "com.typesafe" % "config" % Versions.typesafeConfig
  
  // Logging
  val slf4jApi = "org.slf4j" % "slf4j-api" % Versions.slf4j
  val logback = "ch.qos.logback" % "logback-classic" % Versions.logback
  
  // External integrations
  val kafkaClients = "org.apache.kafka" % "kafka-clients" % Versions.kafka
  val awsS3 = "com.amazonaws" % "aws-java-sdk-s3" % Versions.aws
  val deltaCore = "io.delta" %% "delta-core" % Versions.delta
  
  // Testing
  val scalaTest = "org.scalatest" %% "scalatest" % Versions.scalaTest % Test
  val scalaMock = "org.scalamock" %% "scalamock" % "5.2.0" % Test
  
  // Machine Learning
  val netlib = "com.github.fommil.netlib" % "all" % "1.1.2"
}
