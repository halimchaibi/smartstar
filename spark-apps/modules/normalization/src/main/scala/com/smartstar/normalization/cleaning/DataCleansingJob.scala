package com.smartstar.normalization.cleaning

import com.smartstar.common.traits.{SparkJob, ConfigurableJob}
import com.smartstar.common.config.AppConfig
import com.smartstar.common.constants.ColumnConstants
import org.apache.spark.sql.{DataFrame, SaveMode}
import org.apache.spark.sql.functions._

class DataCleansingJob extends SparkJob with ConfigurableJob {
  
  override def appName: String = "SmartStar-Data-Cleansing"
  override def config: AppConfig = AppConfig.load()
  
  override def run(args: Array[String]): Unit = {
    validateConfig()
    
    logInfo(s"Starting $appName")
    
    val inputPath = args.headOption.getOrElse("data/raw/")
    val outputPath = args.lift(1).getOrElse("data/cleansed/")
    
    // Read raw data
    val rawDF = spark.read.parquet(inputPath)
    logInfo(s"Read ${rawDF.count()} raw records")
    
    // Apply cleansing rules
    val cleansedDF = cleanseData(rawDF)
    logInfo(s"Cleansed data contains ${cleansedDF.count()} records")
    
    // Write cleansed data
    writeCleanData(cleansedDF, outputPath)
    
    logInfo(s"Successfully completed $appName")
  }
  
  private def cleanseData(df: DataFrame): DataFrame = {
    logInfo("Applying data cleansing rules")
    
    df
      // Remove duplicates
      .dropDuplicates()
      
      // Add audit columns
      .withColumn(ColumnConstants.PROCESSING_DATE, current_date())
      .withColumn(ColumnConstants.CREATED_AT, current_timestamp())
      
      // Clean string columns
      .withColumn("email", lower(trim(col("email"))))
      .withColumn("phone", regexp_replace(col("phone"), "[^0-9+]", ""))
      
      // Validate and flag data quality issues
      .withColumn(ColumnConstants.DATA_QUALITY_SCORE, 
        when(col("email").rlike("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"), 1.0)
        .otherwise(0.0))
      
      // Filter out invalid records
      .filter(col(ColumnConstants.DATA_QUALITY_SCORE) > 0.5)
  }
  
  private def writeCleanData(df: DataFrame, outputPath: String): Unit = {
    logInfo(s"Writing cleansed data to $outputPath")
    
    df.write
      .mode(SaveMode.Overwrite)
      .partitionBy(ColumnConstants.PROCESSING_DATE)
      .parquet(outputPath)
  }
}

object DataCleansingJob {
  def main(args: Array[String]): Unit = {
    val job = new DataCleansingJob()
    try {
      job.run(args)
    } finally {
      job.close()
    }
  }
}
