package com.smartstar.common.config
import com.smartstar.common.traits.{Environment, Module}
import com.smartstar.common.utils.LoggingUtils
import com.typesafe.config.{Config, ConfigFactory}

import scala.jdk.CollectionConverters._
import scala.util.{Failure, Success, Try}


case class AppConfig(
    appName: String,
    version: String,
    environment: Environment,
    module: Module,
    rawConfig: Config
)

object AppConfig extends LoggingUtils {

  def load(): AppConfig = {
    val environment = Environment.detect()
    val module = Module.detect().get

    loadForEnvironmentAndModule(environment, module)
  }

  def loadForEnvironmentAndModule(environment: Environment, module: Module): AppConfig = {
    logInfo(
      s"Loading configuration for environment: ${environment.name}, module: ${module.name}"
    )

    // Set system properties for substitution in HOCON (in HOCON include directives the substitution might fail)
    System.setProperty("ENV", environment.name)
    System.setProperty("MODULE_NAME", module.name)

    // Load and resolve the complete configuration
    val rawConfig = loadCompleteConfig(environment, module)

    // Create AppConfig from the resolved configuration
    fromConfig(rawConfig, environment, module)
  }

  private def loadCompleteConfig(environment: Environment, module: Module): Config = {
    try {
      // Load configuration using Typesafe Config's standard loading mechanism

      val resolvedConfig = loadLayered()
      logInfo(s"Successfully loaded configuration for environment: ${environment.name}")
      resolvedConfig
    } catch {
      case ex: Exception =>
        logError(s"Failed to load configuration: ${ex.getMessage}", ex)
        logInfo("Using fallback configuration...")

        // TODO: Fallback configuration or remove in production it might succeed and run slightly using this arbitrary config
        ConfigFactory
          .parseString(s"""
          environment = "$environment"
          app {
            name = "smartstar"
            version = "1.0.0"
          }
          spark {
          }
          """)
          .resolve()
    }
  }

  private def fromConfig(
      rawConfig: Config,
      environment: Environment,
      module: Module
  ): AppConfig = {
    // Validate configuration before creating AppConfig
    validate(rawConfig)

    AppConfig(
      appName = rawConfig.getString("app.name"),
      version = rawConfig.getString("app.version"),
      environment = environment,
      module = module,
      rawConfig = rawConfig
    )
  }

  def logAllConfigEntries(config: Config, prefix: String = ""): Unit = {
    logInfo("=== Configuration Debug Dump ===")

    try {
      // Get all config entries as a flat map
      val allEntries = config.entrySet().asScala

      allEntries.foreach { entry =>
        val key = entry.getKey
        val value = entry.getValue

        // Mask sensitive values
        val maskedValue = if (key.toLowerCase.contains("password") ||
          key.toLowerCase.contains("secret") ||
          key.toLowerCase.contains("key")) {
          "***MASKED***"
        } else {
          value.render()
        }

        logInfo(s"Config[$key] = $maskedValue")
      }
    } catch {
      case ex: Exception =>
        logError(s"Failed to dump config: ${ex.getMessage}", ex)
    }

    logInfo("=== End Configuration Dump ===")
  }

  def loadLayered(): Config = {
    //TODO: Remove the defaulting to development after testing
    val environment = sys.env.getOrElse("ENV", "development")

    // Load in priority order (last wins)
    val layers = Seq(
      "application.conf",
      s"common.conf",
      s"$environment.conf",
    )

    val loadedConfig = layers.foldLeft(ConfigFactory.empty()) { (config, layer) =>
        Try(ConfigFactory.load(layer)).fold(
          ex => {
            logWarn(s"Could not load $layer: ${ex.getMessage}")
            config
          },
          newConfig => {
            logInfo(s"Loaded $layer successfully")
            newConfig.withFallback(config)
          }
        )
      }
      .resolve()

    logAllConfigEntries(loadedConfig)
    loadedConfig
  }

  // Utility methods
  def validate(config: Config): Boolean =
    Try {
      debugConfig(config)
      val requiredPaths = Seq(
        "app.name",
        "app.version",
        "environment",
        "spark.master",
      )

      requiredPaths.foreach { path =>
        if (!config.hasPath(path)) {
          throw new RuntimeException(s"Missing required configuration: $path")
        }
      }
      true
    } match {
      case Success(_) => true
      case Failure(ex) =>
        logError(s"Configuration validation failed: ${ex.getMessage}", ex)
        false
    }

  def debugConfig(config: Config): Unit = {
    logInfo("=== Quick Config Debug ===")

    // Log some basic info
    logInfo(s"Config is empty: ${config.isEmpty}")
    logInfo(s"Config origin: ${config.origin()}")

    // Try to access a few known paths
    val testPaths = Seq("environment", "module", "app", "spark")
    testPaths.foreach { path =>
      if (config.hasPath(path)) {
        logInfo(s"Has path '$path': ${config.getValue(path).render()}")
      } else {
        logWarn(s"Missing path: '$path'")
      }
    }

    // Log first 20 entries
    try {
      val entries = config.entrySet().asScala.take(20)
      logInfo("First 10 config entries:")
      entries.foreach { entry =>
        logInfo(s"  ${entry.getKey} = ${entry.getValue.render()}")
      }
    } catch {
      case ex: Exception =>
        logError(s"Failed to read entries: ${ex.getMessage}")
    }
  }
}
