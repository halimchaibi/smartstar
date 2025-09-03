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
    //TODO: add production-specific validations
  }

  private def validateTestConfig(): Unit = {
    logInfo("Validating test-specific configuration...")
    // Test environment should use minimal resources
    //TODO: add test-specific validations

  }
}
