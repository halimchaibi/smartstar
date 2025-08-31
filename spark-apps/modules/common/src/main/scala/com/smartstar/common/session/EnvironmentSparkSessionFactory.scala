package com.smartstar.common.session

import org.apache.spark.sql.SparkSession
import com.smartstar.common.config.{Environment, SparkSessionConfig}
import com.smartstar.common.utils.LoggingUtils

object EnvironmentSparkSessionFactory extends LoggingUtils {

  def createSession(
                     appName: String,
                     config: SparkSessionConfig,
                     environment: Environment,
                     additionalConfigs: Map[String, String] = Map.empty
                   ): SparkSession = {

    logInfo(s"Creating Spark session for application: $appName in environment: ${environment.name}")

    val builder = SparkSession.builder()
      .appName(s"$appName-${environment.name}")

    // Apply environment-specific configurations
    applyEnvironmentConfigs(builder, config, environment)

    // Apply additional custom configurations
    additionalConfigs.foreach { case (key, value) =>
      builder.config(key, value)
    }

    val session = builder.getOrCreate()

    logSessionInfo(session, environment)

    session
  }

  private def applyEnvironmentConfigs(
                                       builder: SparkSession.Builder,
                                       config: SparkSessionConfig,
                                       environment: Environment
                                     ): Unit = {

    // Basic configurations
    builder.master(config.master)
    builder.config("spark.executor.memory", config.executorMemory)
    builder.config("spark.executor.cores", config.executorCores.toString)
    builder.config("spark.driver.memory", config.driverMemory)

    // Dynamic allocation
    if (config.dynamicAllocation.enabled) {
      builder.config("spark.dynamicAllocation.enabled", "true")
      builder.config("spark.dynamicAllocation.minExecutors", config.dynamicAllocation.minExecutors.toString)
      builder.config("spark.dynamicAllocation.maxExecutors", config.dynamicAllocation.maxExecutors.toString)
      builder.config("spark.dynamicAllocation.initialExecutors", config.dynamicAllocation.initialExecutors.toString)

      config.dynamicAllocation.targetExecutors.foreach { target =>
        builder.config("spark.dynamicAllocation.targetExecutors", target.toString)
      }
    }

    // Performance configurations
    val perf = config.performance
    builder.config("spark.sql.adaptive.enabled", perf.adaptiveQueryEnabled.toString)
    builder.config("spark.sql.adaptive.coalescePartitions.enabled", perf.adaptiveCoalescePartitions.toString)
    builder.config("spark.sql.adaptive.skewJoin.enabled", perf.adaptiveSkewJoin.toString)
    builder.config("spark.sql.shuffle.partitions", perf.shufflePartitions.toString)
    builder.config("spark.serializer", perf.serializer)

    // Kryo serialization
    if (perf.kryo.enabled) {
      builder.config("spark.kryo.buffer", perf.kryo.bufferSize)
      builder.config("spark.kryo.buffer.max", perf.kryo.maxBufferSize)
      builder.config("spark.kryo.registrationRequired", perf.kryo.registrationRequired.toString)
    }

    // Monitoring configurations
    val monitoring = config.monitoring
    builder.config("spark.ui.enabled", monitoring.uiEnabled.toString)
    monitoring.uiPort.foreach { port =>
      builder.config("spark.ui.port", port.toString)
    }

    if (monitoring.eventLogEnabled) {
      builder.config("spark.eventLog.enabled", "true")
      monitoring.eventLogDir.foreach { dir =>
        builder.config("spark.eventLog.dir", dir)
      }
    }

    // Storage configurations
    val storage = config.storage
    builder.config("spark.storage.level", storage.level)
    builder.config("spark.storage.memoryFraction", storage.fraction.toString)
    builder.config("spark.storage.safetyFraction", storage.safeFraction.toString)

    // Networking configurations
    val networking = config.networking
    builder.config("spark.network.timeout", networking.timeout)
    builder.config("spark.task.maxRetries", networking.maxRetries.toString)
    builder.config("spark.task.retryWait", networking.retryWait)

    // Apply environment-specific optimizations
    applyEnvironmentOptimizations(builder, environment)

    // Apply custom configurations
    config.customConfigs.foreach { case (key, value) =>
      builder.config(key, value)
    }
  }

  private def applyEnvironmentOptimizations(
                                             builder: SparkSession.Builder,
                                             environment: Environment
                                           ): Unit = {

    environment match {
      case Environment.Development =>
        logInfo("Applying development environment optimizations")
        builder.config("spark.ui.showConsoleProgress", "true")
        builder.config("spark.sql.execution.arrow.maxRecordsPerBatch", "1000")
        builder.config("spark.sql.adaptive.advisoryPartitionSizeInBytes", "128MB")

      case Environment.Staging =>
        logInfo("Applying staging environment optimizations")
        builder.config("spark.sql.execution.arrow.maxRecordsPerBatch", "10000")
        builder.config("spark.sql.adaptive.advisoryPartitionSizeInBytes", "256MB")
        builder.config("spark.sql.adaptive.nonEmptyPartitionRatioForBroadcastJoin", "0.2")

      case Environment.Production =>
        logInfo("Applying production environment optimizations")
        builder.config("spark.sql.execution.arrow.maxRecordsPerBatch", "20000")
        builder.config("spark.sql.adaptive.advisoryPartitionSizeInBytes", "512MB")
        builder.config("spark.sql.adaptive.nonEmptyPartitionRatioForBroadcastJoin", "0.1")
        builder.config("spark.sql.adaptive.maxShuffledHashJoinLocalMapThreshold", "256MB")

        // Production-specific security and monitoring
        builder.config("spark.sql.execution.arrow.pyspark.enabled", "true")
        builder.config("spark.serializer", "org.apache.spark.serializer.KryoSerializer")

      case Environment.Test =>
        logInfo("Applying test environment optimizations")
        builder.config("spark.ui.enabled", "false")
        builder.config("spark.sql.shuffle.partitions", "2")
        builder.config("spark.default.parallelism", "2")
    }
  }

  private def logSessionInfo(session: SparkSession, environment: Environment): Unit = {

    logInfo("=== Spark Session Configuration ===")
    logInfo(s"Application ID: ${session.sparkContext.applicationId}")
    logInfo(s"Application Name: ${session.sparkContext.appName}")
    logInfo(s"Environment: ${environment.name}")
    logInfo(s"Spark Version: ${session.version}")
    logInfo(s"Master: ${session.sparkContext.master}")
    logInfo(s"Default Parallelism: ${session.sparkContext.defaultParallelism}")

    val conf = session.sparkContext.getConf
    logInfo("Key Configurations:")
    logInfo(s"  Executor Memory: ${conf.get("spark.executor.memory", "not set")}")
    logInfo(s"  Executor Cores: ${conf.get("spark.executor.cores", "not set")}")
    logInfo(s"  Driver Memory: ${conf.get("spark.driver.memory", "not set")}")
    logInfo(s"  Shuffle Partitions: ${conf.get("spark.sql.shuffle.partitions", "not set")}")
    logInfo("====================================")
  }
}