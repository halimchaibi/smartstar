package com.smartstar.common.traits

import com.smartstar.common.config.{AppConfig, Environment}
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
    
    // Module-specific validation
    config.module.foreach { moduleName =>
      validateModuleConfig(moduleName)
    }
    
    logInfo("Configuration validation completed successfully")
  }
  
  private def validateProductionConfig(): Unit = {
    logInfo("Validating production-specific configuration...")
    
    // Production should not use local Spark master
    require(!config.sparkConfig.master.startsWith("local"), 
      "Production environment should not use local Spark master")
    
    // Production should have proper database configuration
    require(!config.databaseConfig.host.contains("localhost"), 
      "Production environment should not use localhost database")
    
    // Production should have SSL enabled for database
    require(config.databaseConfig.ssl, 
      "Production environment should use SSL for database connections")
  }
  
  private def validateTestConfig(): Unit = {
    logInfo("Validating test-specific configuration...")
    
    // Test environment should use minimal resources
    val sparkConfig = config.sparkConfig
    if (sparkConfig.executorCores > 2) {
      logWarn("Test environment using more than 2 executor cores - consider reducing for faster tests")
    }
  }
  
  private def validateModuleConfig(moduleName: String): Unit = {
    logInfo(s"Validating module-specific configuration for: $moduleName")
    
    moduleName.toLowerCase match {
      case "ingestion" =>
        // Ingestion should have Kafka config if it's a streaming job
        if (config.kafkaConfig.bootstrapServers.isEmpty) {
          logWarn("Ingestion module without Kafka configuration - only batch processing will be available")
        }
        
      case "analytics" =>
        // Analytics might need specific ML libraries
        logInfo("Analytics module configuration validated")
        
      case "normalization" =>
        // Normalization should have data quality rules enabled
        if (!config.dataQualityConfig.enabled) {
          logWarn("Data quality validation is disabled for normalization module")
        }
        
      case _ =>
        logInfo(s"No specific validation rules for module: $moduleName")
    }
  }
  
  /**
   * Get configuration value with optional override from environment variables
   */
  def getConfigValue(path: String, envOverride: Option[String] = None): Option[String] = {
    envOverride.flatMap(env => Option(System.getenv(env)))
      .orElse {
        if (config.rawConfig.hasPath(path)) {
          Some(config.rawConfig.getString(path))
        } else {
          None
        }
      }
  }
  
  /**
   * Get required configuration value with proper error handling
   */
  def getRequiredConfigValue(path: String, envOverride: Option[String] = None): String = {
    getConfigValue(path, envOverride).getOrElse {
      throw new IllegalStateException(s"Required configuration value not found: $path")
    }
  }
}
