package com.smartstar.analytics.batch

import com.smartstar.common.traits.{SparkJob, ConfigurableJob}
import com.smartstar.common.config.AppConfig
import org.apache.spark.sql.{DataFrame, SaveMode}
import org.apache.spark.sql.functions._

class AggregationJob extends SparkJob with ConfigurableJob {
  
  override def appName: String = "SmartStar-Aggregation"
  override def config: AppConfig = AppConfig.load()
  
  override def run(args: Array[String]): Unit = {
    validateConfig()
    
    logInfo(s"Starting $appName")
    
    val inputPath = args.headOption.getOrElse("data/cleansed/")
    val outputPath = args.lift(1).getOrElse("data/aggregated/")
    val aggregationType = args.lift(2).getOrElse("daily")
    
    // Read cleansed data
    val df = spark.read.parquet(inputPath)
    logInfo(s"Read ${df.count()} records for aggregation")
    
    // Perform aggregations
    val aggregatedDF = performAggregations(df, aggregationType)
    
    // Write aggregated data
    writeAggregatedData(aggregatedDF, outputPath, aggregationType)
    
    logInfo(s"Successfully completed $appName")
  }
  
  private def performAggregations(df: DataFrame, aggregationType: String): DataFrame = {
    logInfo(s"Performing $aggregationType aggregations")
    
    val dateColumn = aggregationType match {
      case "hourly" => date_trunc("hour", col("created_at"))
      case "daily" => date_trunc("day", col("created_at"))
      case "monthly" => date_trunc("month", col("created_at"))
      case _ => date_trunc("day", col("created_at"))
    }
    
    df.groupBy(dateColumn.alias("period"))
      .agg(
        count("*").alias("total_records"),
        sum("amount").alias("total_amount"),
        avg("amount").alias("avg_amount"),
        max("amount").alias("max_amount"),
        min("amount").alias("min_amount"),
        countDistinct("customer_id").alias("unique_customers")
      )
      .withColumn("aggregation_type", lit(aggregationType))
      .withColumn("generated_at", current_timestamp())
  }
  
  private def writeAggregatedData(df: DataFrame, outputPath: String, aggregationType: String): Unit = {
    logInfo(s"Writing aggregated data to $outputPath")
    
    df.write
      .mode(SaveMode.Overwrite)
      .partitionBy("aggregation_type")
      .parquet(s"$outputPath/$aggregationType")
  }
}

object AggregationJob {
  def main(args: Array[String]): Unit = {
    val job = new AggregationJob()
    try {
      job.run(args)
    } finally {
      job.close()
    }
  }
}
