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
    
    // Production environment validations
    require(config.environment.isProduction, "Expected production environment")
    
    // Validate critical production settings exist
    val rawConfig = config.rawConfig
    require(rawConfig.hasPath("spark.master"), "Spark master must be configured for production")
    require(rawConfig.hasPath("database.url"), "Database URL must be configured for production")
    require(rawConfig.hasPath("database.username"), "Database username must be configured for production")
    
    // Production should not use local spark master
    val sparkMaster = rawConfig.getString("spark.master")
    require(!sparkMaster.startsWith("local"), s"Production should not use local Spark master: $sparkMaster")
    
    logInfo("Production configuration validation passed")
  }

  private def validateTestConfig(): Unit = {
    logInfo("Validating test-specific configuration...")
    
    // Test environment should use minimal resources
    require(config.environment.isTest, "Expected test environment")
    
    val rawConfig = config.rawConfig
    if (rawConfig.hasPath("spark.master")) {
      val sparkMaster = rawConfig.getString("spark.master")
      require(sparkMaster.startsWith("local"), s"Test environment should use local Spark master: $sparkMaster")
    }
    
    // Test database should be in-memory or test-specific
    if (rawConfig.hasPath("database.url")) {
      val dbUrl = rawConfig.getString("database.url")
      require(dbUrl.contains("h2:mem") || dbUrl.contains("test"), 
        s"Test environment should use in-memory or test database: $dbUrl")
    }
    
    logInfo("Test configuration validation passed")
  }
}
