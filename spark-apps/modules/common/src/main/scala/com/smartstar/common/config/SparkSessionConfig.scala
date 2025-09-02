package com.smartstar.common.config

import com.smartstar.common.traits.Environment
import com.typesafe.config.Config

case class SparkSessionConfig(
  master: String,
  appName: String,
  executorMemory: String,
  executorCores: Int,
  driverMemory: String,
  customConfigs: Map[String, String] = Map.empty
)

object SparkSessionConfig {
  def load(rawConfig: Config, environment: Environment): SparkSessionConfig = {
    SparkSessionConfig(
      master = rawConfig.getString("spark.master"),
      appName = rawConfig.getString("spark.app-name"),
      executorMemory = rawConfig.getString("spark.executor.memory"),
      executorCores = rawConfig.getInt("spark.executor.cores"),
      driverMemory = rawConfig.getString("spark.driver.memory"),
      customConfigs = extractCustomSparkConfigs(rawConfig)
    )
  }

  private def extractCustomSparkConfigs(config: Config): Map[String, String] = {
    import scala.jdk.CollectionConverters._

    if (config.hasPath("spark.hadoop")) {
      config.getConfig("spark.hadoop").entrySet().asScala.map { entry =>
        s"spark.hadoop.${entry.getKey}" -> entry.getValue.unwrapped().toString
      }.toMap
    } else {
      Map.empty
    }
  }
}