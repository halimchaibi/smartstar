package com.smartstar.common.session

import com.smartstar.common.config.AppConfig
import com.smartstar.common.utils.LoggingUtils
import com.typesafe.config.Config
import org.apache.spark.sql.SparkSession

import scala.jdk.CollectionConverters._

object EnvironmentSparkSessionFactory extends LoggingUtils {

  def createSession(
                     config: AppConfig,
                     additionalSparkConfigs: Map[String, String] = Map.empty
                   ): SparkSession = {
    val appName = config.appName
    val environment = config.environment

    logInfo(s"Creating Spark session for application: $appName in environment: $environment")

    val builder = SparkSession
      .builder()
      .master(config.rawConfig.getString("spark.master"))
      .appName(appName)
    // Extract all spark configurations
    val allSparkConfigs = extractAllSparkConfigs(config.rawConfig)

    // Apply all configurations
    allSparkConfigs.foreach { case (key, value) =>
      logDebug(s"Setting Spark config: $key = $value")
      builder.config(key, value)
    }

    applyAdditionalConfigs(builder, additionalSparkConfigs)

    val session = builder.getOrCreate()
    logSessionInfo(session, environment.name, allSparkConfigs.size)
    session
  }

  private def applyAdditionalConfigs(
                                      builder: SparkSession.Builder,
                                      additionalSparkConfigs: Map[String, String] = Map.empty
                                    ): SparkSession.Builder = {
    if (additionalSparkConfigs.nonEmpty) {
      logInfo(s"Applying additional Spark configs: ${additionalSparkConfigs.size} entries")
      additionalSparkConfigs.foreach { case (key, value) =>
        logInfo(s"Additional config: $key = $value")
      }

      additionalSparkConfigs.foldLeft(builder) {
        case (b, (key, value)) => b.config(key, value)
      }
    } else {
      logDebug("No additional Spark configs to apply")
      builder
    }
  }

  /**
   * Extract all Spark configurations using the flatten approach
   */
  //TODO: consider using a simplified method that flattens everything at once
  private def extractAllSparkConfigs(config: Config): Map[String, String] = {
    val allConfigs = scala.collection.mutable.Map[String, String]()

    // Extract executor configs
    if (config.hasPath("spark.executor")) {
      allConfigs ++= flattenConfigWithPrefix(config.getConfig("spark.executor"), "spark.executor")
    }

    // Extract driver configs
    if (config.hasPath("spark.driver")) {
      allConfigs ++= flattenConfigWithPrefix(config.getConfig("spark.driver"), "spark.driver")
    }

    // Extract SQL configs
    if (config.hasPath("spark.sql")) {
      val sqlConfigs = flattenConfigWithPrefix(config.getConfig("spark.sql"), "spark.sql")
      // Handle special mappings for SQL configs
      allConfigs ++= sqlConfigs.map { case (key, value) =>
        key match {
          case "spark.sql.shuffle-partitions" => "spark.sql.shuffle.partitions" -> value
          case "spark.sql.adaptive.advisory-partition-size" =>
            "spark.sql.adaptive.advisoryPartitionSizeInBytes" -> parseSize(value)
          case _ => key -> value
        }
      }
    }

    // Extract UI configs
    if (config.hasPath("spark.ui")) {
      val uiConfigs = flattenConfigWithPrefix(config.getConfig("spark.ui"), "spark.ui")
      // Handle special mappings for UI configs
      allConfigs ++= uiConfigs.map { case (key, value) =>
        key match {
          case "spark.ui.retain-tasks" => "spark.ui.retainedTasks" -> value
          case "spark.ui.retain-stages" => "spark.ui.retainedStages" -> value
          case _ => key -> value
        }
      }
    }

    // Extract dynamic allocation configs
    if (config.hasPath("spark.dynamic-allocation")) {
      val dynamicConfigs = flattenConfigWithPrefix(config.getConfig("spark.dynamic-allocation"), "spark.dynamicAllocation")
      // Handle special mappings (kebab-case to camelCase)
      allConfigs ++= dynamicConfigs.map { case (key, value) =>
        key match {
          case "spark.dynamicAllocation.min-executors" => "spark.dynamicAllocation.minExecutors" -> value
          case "spark.dynamicAllocation.max-executors" => "spark.dynamicAllocation.maxExecutors" -> value
          case "spark.dynamicAllocation.initial-executors" => "spark.dynamicAllocation.initialExecutors" -> value
          case _ => key -> value
        }
      }
    }

    // Extract event log configs
    if (config.hasPath("spark.eventLog")) {
      allConfigs ++= flattenConfigWithPrefix(config.getConfig("spark.eventLog"), "spark.eventLog")
    }

    // Extract debug configs
    if (config.hasPath("spark.debug")) {
      val debugConfigs = flattenConfigWithPrefix(config.getConfig("spark.debug"), "spark.debug")
      // Handle special mappings
      allConfigs ++= debugConfigs.map { case (key, value) =>
        key match {
          case "spark.debug.max-to-string-fields" => "spark.debug.maxToStringFields" -> value
          case _ => key -> value
        }
      }
    }

    // Extract JAR configs
    if (config.hasPath("spark.jars")) {
      val jarConfigs = flattenConfigWithPrefix(config.getConfig("spark.jars"), "spark.jars")
      // Handle arrays properly for JARs
      allConfigs ++= jarConfigs.flatMap { case (key, value) =>
        key match {
          case "spark.jars.packages" =>
            if (value.nonEmpty && value != "[]") Some(key -> value)
            else None
          case "spark.jars.lib" =>
            if (value.nonEmpty && value != "[]") Some("spark.jars" -> value)
            else None
          case _ => Some(key -> value)
        }
      }
    }

    // Extract Hadoop configs (this was already working well!)
    if (config.hasPath("spark.hadoop")) {
      allConfigs ++= flattenConfigWithPrefix(config.getConfig("spark.hadoop"), "spark.hadoop")
    }

    allConfigs.toMap
  }

  /**
   * 1. Handles any level of nesting automatically
   * 2. No need to hardcode every possible config key
   * 3. Future-proof - handles new config keys without code changes
   * 4. Consistent behavior across all config sections
   * 5. Much less code to maintain
   */
  private def flattenConfigWithPrefix(config: Config, prefix: String): Map[String, String] = {
    val configs = scala.collection.mutable.Map[String, String]()

    config.entrySet().asScala.foreach { entry =>
      val key = entry.getKey
      val value = entry.getValue
      val fullKey = s"$prefix.$key"

      value.valueType() match {
        case com.typesafe.config.ConfigValueType.OBJECT =>
          // Recursively flatten nested objects
          val nestedConfig = config.getConfig(key)
          configs ++= flattenConfigWithPrefix(nestedConfig, fullKey)

        case com.typesafe.config.ConfigValueType.LIST =>
          // Handle arrays/lists
          val listValues = config.getStringList(key).asScala
          if (listValues.nonEmpty) {
            configs += fullKey -> listValues.mkString(",")
          }

        case _ =>
          // Handle primitive values (String, Int, Boolean, etc.)
          configs += fullKey -> value.unwrapped().toString
      }
    }

    configs.toMap
  }

  // flatten everything at once
  //TODO: Consider it and refactor teh above code or remove
  private def extractAllSparkConfigsSimplified(config: Config): Map[String, String] = {
    if (config.hasPath("spark")) {
      val sparkConfig = config.getConfig("spark")
      val flatConfigs = flattenConfigWithPrefix(sparkConfig, "spark")

      // Apply any necessary key transformations
      flatConfigs.map { case (key, value) =>
        val transformedKey = transformConfigKey(key)
        val transformedValue = transformConfigValue(key, value)
        transformedKey -> transformedValue
      }.filterNot { case (key, _) =>
        // Filter out keys we don't want to pass to Spark
        key == "spark.master" || key == "spark.app-name"
      }
    } else {
      Map.empty
    }
  }

  /**
   * Transform config keys from kebab-case to the expected Spark format
   */
  private def transformConfigKey(key: String): String = {
    key match {
      // SQL transformations
      case "spark.sql.shuffle-partitions" => "spark.sql.shuffle.partitions"
      case k if k.contains("advisory-partition-size") => k.replace("advisory-partition-size", "advisoryPartitionSizeInBytes")

      // UI transformations
      case "spark.ui.retain-tasks" => "spark.ui.retainedTasks"
      case "spark.ui.retain-stages" => "spark.ui.retainedStages"

      // Dynamic allocation transformations
      case k if k.startsWith("spark.dynamic-allocation") =>
        k.replace("dynamic-allocation", "dynamicAllocation")
          .replace("min-executors", "minExecutors")
          .replace("max-executors", "maxExecutors")
          .replace("initial-executors", "initialExecutors")

      // Debug transformations
      case "spark.debug.max-to-string-fields" => "spark.debug.maxToStringFields"

      // Default: no transformation
      case _ => key
    }
  }

  /**
   * Transform config values (e.g., size parsing)
   */
  private def transformConfigValue(key: String, value: String): String = {
    key match {
      case k if k.contains("advisoryPartitionSizeInBytes") => parseSize(value)
      case _ => value
    }
  }

  private def parseSize(sizeStr: String): String = {
    val size = sizeStr.toUpperCase.trim
    try {
      if (size.endsWith("MB")) {
        val value = size.replace("MB", "").toLong
        (value * 1024 * 1024).toString
      } else if (size.endsWith("GB")) {
        val value = size.replace("GB", "").toLong
        (value * 1024 * 1024 * 1024).toString
      } else if (size.endsWith("KB")) {
        val value = size.replace("KB", "").toLong
        (value * 1024).toString
      } else {
        size // Assume it's already in bytes
      }
    } catch {
      case _: NumberFormatException =>
        logWarn(s"Could not parse size: $sizeStr, using as-is")
        size
    }
  }

  private def logSessionInfo(session: SparkSession, environment: String, configCount: Int): Unit = {
    logInfo("=== Spark Session Created Successfully ===")
    logInfo(s"Application Name: ${session.sparkContext.appName}")
    logInfo(s"Environment: $environment")
    logInfo(s"Master: ${session.sparkContext.master}")
    logInfo(s"Spark Version: ${session.version}")
    logInfo(s"Applied Configurations: $configCount")
    logInfo(s"Default Parallelism: ${session.sparkContext.defaultParallelism}")
    logInfo("=== End Spark Session Info ===")
  }
}