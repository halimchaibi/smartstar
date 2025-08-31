package com.smartstar.common.utils

import org.apache.spark.sql.SparkSession

object SparkSessionHelper extends LoggingUtils {
  
  def createSparkSession(appName: String, master: String = "local[*]"): SparkSession = {
    logInfo(s"Creating Spark session for application: $appName")
    
    SparkSession.builder()
      .appName(appName)
      .master(master)
      .config("spark.sql.adaptive.enabled", "true")
      .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
      .config("spark.sql.adaptive.skewJoin.enabled", "true")
      .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
      .config("spark.sql.execution.arrow.pyspark.enabled", "true")
      .getOrCreate()
  }
  
  def stopSparkSession(spark: SparkSession): Unit = {
    if (spark != null) {
      logInfo("Stopping Spark session")
      spark.stop()
    }
  }
}
