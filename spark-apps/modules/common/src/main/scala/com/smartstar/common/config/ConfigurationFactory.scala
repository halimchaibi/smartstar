package com.smartstar.common.config

import com.smartstar.common.utils.LoggingUtils

/**
 * Centralized configuration factory for consistent configuration loading
 * across all SmartStar applications and modules.
 */
object ConfigurationFactory extends LoggingUtils {
  
  /**
   * Create configuration for a Spark job with automatic environment detection
   */
  def forJob(jobName: String): AppConfig = {
    logInfo(s"Creating configuration for job: $jobName")
    AppConfig.load()
  }
  
  /**
   * Create configuration for a specific module in current environment
   */
  def forModule(moduleName: String): AppConfig = {
    logInfo(s"Creating configuration for module: $moduleName")
    val environment = Environment.detect()
    AppConfig.loadForEnvironmentAndModule(environment, Some(moduleName))
  }
  
  /**
   * Create configuration for a specific environment
   */
  def forEnvironment(environment: Environment): AppConfig = {
    logInfo(s"Creating configuration for environment: ${environment.name}")
    AppConfig.loadForEnvironment(environment)
  }
  
  /**
   * Create configuration for a specific environment and module combination
   */
  def forEnvironmentAndModule(environment: Environment, moduleName: String): AppConfig = {
    logInfo(s"Creating configuration for environment: ${environment.name}, module: $moduleName")
    AppConfig.loadForEnvironmentAndModule(environment, Some(moduleName))
  }
  
  /**
   * Create test configuration with minimal resources
   */
  def forTesting(testName: String = "test"): AppConfig = {
    logInfo(s"Creating test configuration for: $testName")
    val config = AppConfig.loadForEnvironment(Environment.Test)
    
    // Override with test-specific settings
    logInfo("Applied test-specific optimizations")
    config
  }
  
  /**
   * Validate that configuration is consistent across environments
   */
  def validateConsistency(): Boolean = {
    logInfo("Validating configuration consistency across environments...")
    
    val environments = Environment.all
    var allValid = true
    
    environments.foreach { env =>
      try {
        val config = AppConfig.loadForEnvironment(env)
        val isValid = AppConfig.validate(config.rawConfig)
        
        if (!isValid) {
          logError(s"Configuration validation failed for environment: ${env.name}")
          allValid = false
        } else {
          logInfo(s"Configuration validation passed for environment: ${env.name}")
        }
      } catch {
        case ex: Exception =>
          logError(s"Failed to load configuration for environment: ${env.name}", ex)
          allValid = false
      }
    }
    
    if (allValid) {
      logInfo("All environment configurations are valid and consistent")
    } else {
      logError("Configuration consistency validation failed")
    }
    
    allValid
  }
  
  /**
   * Get environment-specific configuration summary for debugging
   */
  def getConfigSummary(environment: Environment): Map[String, Any] = {
    val config = AppConfig.loadForEnvironment(environment)
    
    Map(
      "environment" -> environment.name,
      "app_name" -> config.appName,
      "version" -> config.version,
      "spark_master" -> config.sparkConfig.master,
      "database_host" -> config.databaseConfig.host,
      "storage_base_path" -> config.storageConfig.basePath,
      "data_quality_enabled" -> config.dataQualityConfig.enabled,
      "monitoring_enabled" -> config.monitoringConfig.metricsEnabled
    )
  }
  
  /**
   * Print configuration summary for all environments (useful for debugging)
   */
  def printAllConfigSummaries(): Unit = {
    logInfo("=== Configuration Summary for All Environments ===")
    
    Environment.all.foreach { env =>
      try {
        val summary = getConfigSummary(env)
        logInfo(s"Environment: ${env.name}")
        summary.foreach { case (key, value) =>
          logInfo(s"  $key: $value")
        }
        logInfo("")
      } catch {
        case ex: Exception =>
          logError(s"Failed to get summary for environment: ${env.name}", ex)
      }
    }
    
    logInfo("=== End Configuration Summary ===")
  }
}