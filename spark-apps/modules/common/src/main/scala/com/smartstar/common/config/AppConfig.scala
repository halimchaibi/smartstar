package com.smartstar.common.config
import com.typesafe.config.{Config, ConfigFactory}
import com.smartstar.common.utils.LoggingUtils

import scala.util.{Failure, Success, Try}

case class AppConfig(
                      appName: String,
                      version: String,
                      environment: Environment,
                      module: Option[String],
                      sparkConfig: SparkSessionConfig,
                      databaseConfig: DatabaseConfig,
                      kafkaConfig: KafkaConfig,
                      storageConfig: StorageConfig,
                      monitoringConfig: MonitoringConfig,
                      dataQualityConfig: DataQualityConfig,
                      rawConfig: Config  // ← This holds the complete resolved configuration
                    )

object AppConfig extends LoggingUtils {

  def load(): AppConfig = {
    val environment = Environment.detect()
    val module = detectModule()
    loadForEnvironmentAndModule(environment, module)
  }

  def loadForEnvironment(environment: Environment): AppConfig = {
    loadForEnvironmentAndModule(environment, None)
  }

  def loadForModule(module: String): AppConfig = {
    val environment = Environment.detect()
    loadForEnvironmentAndModule(environment, Some(module))
  }

  def loadForEnvironmentAndModule(environment: Environment, module: Option[String]): AppConfig = {
    logInfo(s"Loading configuration for environment: ${environment.name}, module: ${module.getOrElse("none")}")
    
    // Set system properties for substitution in HOCON
    System.setProperty("environment", environment.name)
    module.foreach(m => System.setProperty("MODULE_NAME", m))

    // Load and resolve the complete configuration
    val rawConfig = loadCompleteConfig(environment, module)

    // Create AppConfig from the resolved configuration
    fromConfig(rawConfig, environment, module)
  }

  private def loadCompleteConfig(environment: Environment, module: Option[String]): Config = {
    try {
      // Load configuration using Typesafe Config's standard loading mechanism
      // This automatically loads application.conf which includes all our config files
      val config = ConfigFactory.load()

      // Resolve all substitutions (${...} variables)
      val resolvedConfig = config.resolve()

      logInfo(s"Successfully loaded configuration for environment: ${environment.name}")
      resolvedConfig
    } catch {
      case ex: Exception =>
        logError(s"Failed to load configuration: ${ex.getMessage}", ex)
        logInfo("Using fallback configuration...")

        // Fallback configuration
        ConfigFactory.parseString(s"""
          environment = "${environment.name}"
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
            dynamic-allocation.enabled = false
            dynamic-allocation.min-executors = 1
            dynamic-allocation.max-executors = 4
            dynamic-allocation.initial-executors = 2
            sql.shuffle-partitions = 8
            sql.adaptive.enabled = true
            sql.adaptive.coalesce-partitions = true
            sql.adaptive.skew-join = true
            serializer = "org.apache.spark.serializer.KryoSerializer"
            kryo.buffer = "64k"
            kryo.buffer-max = "64m"
            kryo.registration-required = false
            ui.enabled = true
            eventLog.enabled = false
            storage.level = "MEMORY_AND_DISK"
            storage.fraction = "0.6"
            storage.safety-fraction = "0.9"
            network.timeout = "120s"
            network.max-retries = 3
            network.retry-wait = "1s"
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
            connection-timeout = "30s"
          }

          kafka {
            bootstrap-servers = "localhost:9092"
            group-id = "smartstar-dev"
            auto-offset-reset = "earliest"
            session-timeout = "30s"
            heartbeat-interval = "3s"
            consumer.max-poll-records = 500
            consumer.fetch-min-bytes = 1024
            consumer.max-partition-fetch-bytes = 1048576
            producer.batch-size = 16384
            producer.linger-ms = 1
            producer.compression-type = "snappy"
            producer.max-request-size = 2097152
          }

          storage {
            base-path = "/tmp/smartstar"
            formats.input = "parquet"
            formats.output = "delta"
            formats.intermediate = "parquet"
            compression = "snappy"
            paths.checkpoints = "/tmp/smartstar/checkpoints"
          }

          monitoring {
            metrics.enabled = true
            metrics.reporting-interval = "30s"
            health-check.enabled = true
            ui.enabled = true
            eventLog.enabled = false
          }

          data-quality {
            enabled = true
            fail-on-error = false
            rules.null-check = true
            rules.format-validation = true
            rules.range-validation = true
            rules.custom-validation = true
            thresholds.error-rate = 0.05
            thresholds.completeness = 0.95
            thresholds.uniqueness = 0.98
          }
        """).resolve()
    }
  }

  private def fromConfig(rawConfig: Config, environment: Environment, module: Option[String]): AppConfig = {
    // Validate configuration before creating AppConfig
    validate(rawConfig)
    
    AppConfig(
      appName = rawConfig.getString("app.name"),
      version = rawConfig.getString("app.version"),
      environment = environment,
      module = module,

      sparkConfig = SparkSessionConfig.load(rawConfig, environment),
      databaseConfig = DatabaseConfig.load(rawConfig),
      kafkaConfig = KafkaConfig.load(rawConfig),
      storageConfig = StorageConfig.load(rawConfig),
      monitoringConfig = MonitoringConfig.load(rawConfig),
      dataQualityConfig = DataQualityConfig.load(rawConfig),

      rawConfig = rawConfig  // ← Store the complete resolved config
    )
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
        "app.version",
        "environment",
        "spark.master",
        "database.host",
        "database.driver",
        "storage.base-path"
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
  }
}