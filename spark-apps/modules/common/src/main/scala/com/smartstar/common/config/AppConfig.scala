package com.smartstar.common.config

import com.typesafe.config.{Config, ConfigFactory}

case class AppConfig(
  appName: String,
  sparkConfig: SparkConfig,
  databaseConfig: DatabaseConfig
)

object AppConfig {
  def load(): AppConfig = {
    val config = ConfigFactory.load()
    AppConfig(
      appName = config.getString("app.name"),
      sparkConfig = SparkConfig.load(config.getConfig("spark")),
      databaseConfig = DatabaseConfig.load(config.getConfig("database"))
    )
  }
  
  def loadFromPath(configPath: String): AppConfig = {
    val config = ConfigFactory.load(configPath)
    load()
  }
}
