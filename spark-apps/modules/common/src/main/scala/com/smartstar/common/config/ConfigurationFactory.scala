package com.smartstar.common.config

import com.smartstar.common.traits.{Environment, Module}
import com.smartstar.common.utils.LoggingUtils
import com.smartstar.common.config.AppConfig

/**
 * Centralized configuration factory for consistent configuration loading across all SmartStar
 * applications and modules.
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
   * Create configuration for a specific environment and module combination
   */
  def forEnvironmentAndModule(environment: Environment, module: Module): AppConfig = {
    logInfo(s"Creating configuration for environment: ${environment.name}, module: $module.name")
    AppConfig.loadForEnvironmentAndModule(environment, module)
  }

  def forEnvironment(environment: Environment, module: Module): AppConfig = {
    logInfo(s"Creating configuration for environment: ${environment.name}, module: $module.name")
    AppConfig.loadForEnvironmentAndModule(environment, module)
  }

  def forModule(environment: Environment, module: Module): AppConfig = {
    logInfo(s"Creating configuration for environment: ${environment.name}, module: $module.name")
    AppConfig.loadForEnvironmentAndModule(environment, module)
  }

  /**
   * Validate that configuration is consistent across environments
   */
  def validateConsistency(): Boolean = {
    logInfo("Validating configuration consistency across environments...")

    val environments = Environment.all
    val modules = Module.all

    var allValid = true

    environments.foreach { env =>
      modules.foreach { module =>
        try {
          //TODO: needs refactor to avoid loading multiple times the same config
          val config = AppConfig.loadForEnvironmentAndModule(env, module)
          val isValid = AppConfig.validate(config.rawConfig)

          if (!isValid) {
            logError(s"Configuration validation failed for environment: ${env.name}, module: ${module.name}")
            allValid = false
          } else {
            logInfo(s"Configuration validation passed for environment: ${env.name}, module: ${module.name}")
          }
        } catch {
          case ex: Exception =>
            logError(s"Failed to load configuration for environment: ${env.name}, module: ${module.name}", ex)
            allValid = false
        }
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
    val config = AppConfig.loadForEnvironmentAndModule(environment, Module.Core)

    Map(
      "environment" -> environment.name,
      "app_name" -> config.appName,
      "version" -> config.version,
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
