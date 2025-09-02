package com.smartstar.common.traits

import com.smartstar.common.config.AppConfig
import com.smartstar.common.utils.LoggingUtils

trait ConfigurableJob extends LoggingUtils {
  def config: AppConfig

  def validateConfig(): Unit = {
    logInfo("Validating job configuration...")

    // Basic config validation
    require(config.appName.nonEmpty, "Application name cannot be empty")
    require(config.version.nonEmpty, "Application version cannot be empty")

    // Environment-specific validation
    config.environment match {
      case Environment.Production =>
        validateProductionConfig()
      case Environment.Test =>
        validateTestConfig()
      case _ =>
        logInfo(s"Using ${config.environment.name} environment configuration")
    }

    logInfo("Configuration validation completed successfully")
  }

  private def validateProductionConfig(): Unit = {
    logInfo("Validating production-specific configuration...")

    // Production should not use local Spark master
    require(
      !config.sparkConfig.master.startsWith("local"),
      "Production environment should not use local Spark master"
    )

    // Production should have proper database configuration
//    require(
//      !config.databaseConfig.host.contains("localhost"),
//      "Production environment should not use localhost database"
//    )
//
//    // Production should have SSL enabled for database
//    require(
//      config.databaseConfig.ssl,
//      "Production environment should use SSL for database connections"
//    )
  }

  private def validateTestConfig(): Unit = {
    logInfo("Validating test-specific configuration...")

    // Test environment should use minimal resources
    val sparkConfig = config.sparkConfig
    if (sparkConfig.executorCores > 2) {
      logWarn(
        "Test environment using more than 2 executor cores - consider reducing for faster tests"
      )
    }
  }
}
