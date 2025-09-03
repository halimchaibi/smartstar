package com.smartstar.ingestion.batch

import com.smartstar.common.config.{AppConfig, ConfigurationFactory}
import com.smartstar.common.models.{JobResult, JobStatus}
import com.smartstar.common.traits.{ConfigurableJob, Environment, EnvironmentAwareSparkJob, Module}
import com.smartstar.common.utils.DateTimeUtils
import org.apache.spark.sql.{DataFrame, SaveMode}

class FileIngestionJob extends EnvironmentAwareSparkJob with ConfigurableJob {

  override def appName: String = "SmartStar-File-Ingestion"
  override def config: AppConfig =
    ConfigurationFactory.forEnvironmentAndModule(Environment.Development, Module.Ingestion)

  override def run(args: Array[String]): Unit = {
    validateConfig()

    val startTime = DateTimeUtils.getCurrentTimestamp
    logInfo(s"Starting $appName")

    try {
      // Parse arguments
      val inputPath = args.headOption.getOrElse("data/input/")
      val outputPath = args.lift(1).getOrElse("data/output/")
      val format = args.lift(2).getOrElse("csv")

      // Read data
      val df = readData(inputPath, format)
      val recordCount = df.count()

      logInfo(s"Read $recordCount records from $inputPath")

      // Basic data validation
      validateData(df)

      // Write data
      writeData(df, outputPath)

      val endTime = DateTimeUtils.getCurrentTimestamp
      val result = JobResult(
        jobName = appName,
        status = JobStatus.Success,
        startTime = startTime,
        endTime = Some(endTime),
        recordsProcessed = recordCount
      )

      logInfo(
        s"Successfully completed $appName. Processed $recordCount records in ${result.duration.get}ms"
      )

    } catch {
      case ex: Exception =>
        val endTime = DateTimeUtils.getCurrentTimestamp
        val result = JobResult(
          jobName = appName,
          status = JobStatus.Failed,
          startTime = startTime,
          endTime = Some(endTime),
          errorMessage = Some(ex.getMessage)
        )
        logError(s"${result.status}: Failed to execute ${result.jobName}", ex)
        throw ex
    }
  }

  private def readData(inputPath: String, format: String): DataFrame = {
    logInfo(s"Reading data from $inputPath in $format format")

    format.toLowerCase match {
      case "csv" =>
        spark.read
          .option("header", "true")
          .option("inferSchema", "true")
          .csv(inputPath)
      case "json" =>
        spark.read.json(inputPath)
      case "parquet" =>
        spark.read.parquet(inputPath)
      case _ =>
        throw new IllegalArgumentException(s"Unsupported format: $format")
    }
  }

  private def validateData(df: DataFrame): Unit = {
    logInfo("Validating data quality")

    val totalRecords = df.count()
    val nullCount = df.filter(df.columns.map(col => df(col).isNull).reduce(_ || _)).count()

    logInfo(s"Total records: $totalRecords, Records with nulls: $nullCount")

    if (totalRecords == 0) {
      throw new IllegalStateException("No data found to process")
    }
  }

  private def writeData(df: DataFrame, outputPath: String): Unit = {
    logInfo(s"Writing data to $outputPath")

    df.write
      .mode(SaveMode.Overwrite)
      .option("path", outputPath)
      .parquet(outputPath)
  }
}

object FileIngestionJob {
  def main(args: Array[String]): Unit = {
    val job = new FileIngestionJob()
    try {
      job.run(args)
    } finally {
      job.close()
    }
  }
}
