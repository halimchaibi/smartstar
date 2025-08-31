package com.smartstar.common.traits

import org.apache.spark.sql.SparkSession
import com.smartstar.common.config.AppConfig
import com.smartstar.common.utils.LoggingUtils

trait SparkJob extends LoggingUtils {
  
  def appName: String
  def config: AppConfig
  
  protected lazy val spark: SparkSession = SparkSession
    .builder()
    .appName(appName)
    .config("spark.sql.adaptive.enabled", "true")
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
    .config("spark.sql.adaptive.skewJoin.enabled", "true")
    .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
    .getOrCreate()
    
  def run(args: Array[String]): Unit
  
  def close(): Unit = {
    if (spark != null) {
      spark.stop()
    }
  }
}
