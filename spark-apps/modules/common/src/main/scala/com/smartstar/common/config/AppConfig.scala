package com.smartstar.common.config
import com.typesafe.config.{Config, ConfigFactory}

import scala.util.{Failure, Success, Try}

case class AppConfig(
                      appName: String,
                      version: String,
                      environment: String,
                      module: Option[String],
                      sparkConfig: SparkSessionConfig,
                      databaseConfig: DatabaseConfig,
                      kafkaConfig: KafkaConfig,
                      storageConfig: StorageConfig,
                      monitoringConfig: MonitoringConfig,
                      rawConfig: Config  // ← This holds the complete resolved configuration
                    )

object AppConfig {

  def load(): AppConfig = {
    val environment = detectEnvironment()
    val module = detectModule()
    loadForEnvironmentAndModule(environment, module)
  }

  def loadForEnvironment(environment: String): AppConfig = {
    loadForEnvironmentAndModule(environment, None)
  }

  def loadForModule(module: String): AppConfig = {
    val environment = detectEnvironment()
    loadForEnvironmentAndModule(environment, Some(module))
  }

  def loadForEnvironmentAndModule(environment: String, module: Option[String]): AppConfig = {
    // Set system properties for substitution in HOCON
    System.setProperty("environment", environment)
    module.foreach(m => System.setProperty("MODULE_NAME", m))

    // Load and resolve the complete configuration
    val rawConfig = loadCompleteConfig(environment, module)

    // Create AppConfig from the resolved configuration
    fromConfig(rawConfig, environment, module)
  }

  private def loadCompleteConfig(environment: String, module: Option[String]): Config = {
    try {
      // Load configuration using Typesafe Config's standard loading mechanism
      // This automatically loads application.conf which includes all our config files
      val config = ConfigFactory.load()

      // Resolve all substitutions (${...} variables)
      val resolvedConfig = config.resolve()

      resolvedConfig
    } catch {
      case ex: Exception =>
        println(s"Failed to load configuration: ${ex.getMessage}")
        println("Using fallback configuration...")

        // Fallback configuration
        ConfigFactory.parseString(s"""
          environment = "$environment"
          ${module.map(m => s"""module = "$m"""").getOrElse("")}

          app {
            name = "smartstar"
            version = "1.0.0"
          }

          spark {
            master = "local[*]"
            executor.memory = "2g"
            executor.cores = 2
            driver.memory = "1g"
          }

          database {
            host = "localhost"
            port = 5432
            name = "smartstar"
            username = "smartstar_user"
            password = "smartstar_password"
            driver = "org.postgresql.Driver"
            ssl = false
            connection-pool-size = 10
          }

          storage {
            base-path = "/tmp/smartstar"
          }
        """).resolve()
    }
  }

  private def fromConfig(rawConfig: Config, environment: String, module: Option[String]): AppConfig = {
    AppConfig(
      appName = rawConfig.getString("app.name"),
      version = rawConfig.getString("app.version"),
      environment = environment,
      module = module,

      sparkConfig = SparkSessionConfig.load(rawConfig, Environment.fromString(environment)),
      databaseConfig = DatabaseConfig.load(rawConfig),
      kafkaConfig = KafkaConfig.load(rawConfig),
      storageConfig = StorageConfig.load(rawConfig),
      monitoringConfig = MonitoringConfig.load(rawConfig),

      rawConfig = rawConfig  // ← Store the complete resolved config
    )
  }

  private def detectEnvironment(): String = {
    Seq("SPARK_ENV", "ENVIRONMENT", "ENV")
      .flatMap(sys.env.get)
      .headOption
      .getOrElse("development")
  }

  private def detectModule(): Option[String] = {
    sys.env.get("MODULE_NAME")
      .orElse(sys.props.get("MODULE_NAME"))
  }

  // Utility methods
  def validate(config: Config): Boolean = {
    Try {
      val requiredPaths = Seq(
        "app.name",
        "environment",
        "spark.master",
        "database.driver"
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
        println(s"Configuration validation failed: ${ex.getMessage}")
        false
    }
  }
}