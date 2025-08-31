package com.smartstar.common.constants

object AppConstants {
  val APP_NAME = "SmartStar"
  val VERSION = "1.0.0"
  
  // Data formats
  val PARQUET_FORMAT = "parquet"
  val JSON_FORMAT = "json"
  val CSV_FORMAT = "csv"
  val AVRO_FORMAT = "avro"
  val DELTA_FORMAT = "delta"
  
  // Database drivers
  val POSTGRESQL_DRIVER = "org.postgresql.Driver"
  val MYSQL_DRIVER = "com.mysql.cj.jdbc.Driver"
  val ORACLE_DRIVER = "oracle.jdbc.driver.OracleDriver"
  val SQLSERVER_DRIVER = "com.microsoft.sqlserver.jdbc.SQLServerDriver"
  
  // Kafka topics
  val DEFAULT_KAFKA_TOPIC = "smartstar-events"
  val ERROR_TOPIC = "smartstar-errors"
  
  // Checkpointing
  val CHECKPOINT_LOCATION = "/tmp/spark-checkpoint"
}
