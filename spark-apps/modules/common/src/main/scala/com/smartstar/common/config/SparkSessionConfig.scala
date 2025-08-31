package com.smartstar.common.config

import com.typesafe.config.Config

import scala.concurrent.duration.Duration

case class SparkSessionConfig(
  master: String,
  appName: String,
  executorMemory: String,
  executorCores: Int,
  driverMemory: String,
  dynamicAllocation: DynamicAllocationConfig,
  performance: PerformanceConfig,
  monitoring: MonitoringConfig,
  storage: StorageConfig,
  networking: NetworkingConfig,
  customConfigs: Map[String, String] = Map.empty
)

object SparkSessionConfig {
  def load(rawConfig: Config, environment: Environment): SparkSessionConfig = {
    SparkSessionConfig(
      master = rawConfig.getString("spark.master"),
      appName = rawConfig.getString("spark.app-name"),
      executorMemory = rawConfig.getString("spark.executor.memory"),
      executorCores = rawConfig.getInt("spark.executor.cores"),
      driverMemory = rawConfig.getString("spark.driver.memory"),

      dynamicAllocation = DynamicAllocationConfig(
        enabled = rawConfig.getBoolean("spark.dynamic-allocation.enabled"),
        minExecutors = rawConfig.getInt("spark.dynamic-allocation.min-executors"),
        maxExecutors = rawConfig.getInt("spark.dynamic-allocation.max-executors"),
        initialExecutors = rawConfig.getInt("spark.dynamic-allocation.initial-executors")
      ),

      performance = PerformanceConfig(
        adaptiveQueryEnabled = rawConfig.getBoolean("spark.sql.adaptive.enabled"),
        adaptiveCoalescePartitions = rawConfig.getBoolean("spark.sql.adaptive.coalesce-partitions"),
        adaptiveSkewJoin = rawConfig.getBoolean("spark.sql.adaptive.skew-join"),
        shufflePartitions = rawConfig.getInt("spark.sql.shuffle-partitions"),
        serializer = rawConfig.getString("spark.serializer"),
        kryo = KryoConfig(
          enabled = rawConfig.getString("spark.serializer").contains("Kryo"),
          bufferSize = rawConfig.getString("spark.kryo.buffer"),
          maxBufferSize = rawConfig.getString("spark.kryo.buffer-max"),
          registrationRequired = rawConfig.getBoolean("spark.kryo.registration-required")
        )
      ),
      monitoring = MonitoringConfig.load(rawConfig),
      storage = StorageConfig.load(rawConfig),
      networking = NetworkingConfig(
        timeout = rawConfig.getString("spark.network.timeout"),
        maxRetries = rawConfig.getInt("spark.network.max-retries"),
        retryWait = rawConfig.getString("spark.network.retry-wait")
      ),
      customConfigs = extractCustomSparkConfigs(rawConfig)
    )
      /*,

      monitoring = MonitoringConfig(
        uiEnabled = rawConfig.getBoolean("spark.ui.enabled"),
        uiPort = if (rawConfig.hasPath("spark.ui.port")) Some(rawConfig.getInt("spark.ui.port")) else None,
        historyServerEnabled = rawConfig.getBoolean("spark.eventLog.enabled"),
        eventLogEnabled = rawConfig.getBoolean("spark.eventLog.enabled"),
        eventLogDir = if (rawConfig.hasPath("spark.eventLog.dir")) Some(rawConfig.getString("spark.eventLog.dir")) else None,
        metricsEnabled = rawConfig.getBoolean("monitoring.metrics.enabled")
      ),

      storage = StorageConfig(
        level = rawConfig.getString("spark.storage.level"),
        fraction = rawConfig.getDouble("spark.storage.fraction"),
        safeFraction = rawConfig.getDouble("spark.storage.safe-fraction")
      ),

      networking = NetworkingConfig(
        timeout = rawConfig.getString("spark.network.timeout"),
        maxRetries = rawConfig.getInt("spark.network.max-retries"),
        retryWait = rawConfig.getString("spark.network.retry-wait")
      ),

      customConfigs = extractCustomSparkConfigs(rawConfig)
    )
    */
  }

  private def extractCustomSparkConfigs(config: Config): Map[String, String] = {
    import scala.jdk.CollectionConverters._

    if (config.hasPath("spark.hadoop")) {
      config.getConfig("spark.hadoop").entrySet().asScala.map { entry =>
        s"spark.hadoop.${entry.getKey}" -> entry.getValue.unwrapped().toString
      }.toMap
    } else {
      Map.empty
    }
  }
}

case class KafkaConfig(
                        bootstrapServers: String,
                        groupId: String,
                        autoOffsetReset: String,
                        sessionTimeout: Duration,
                        heartbeatInterval: Duration,
                        consumerConfig: KafkaConsumerConfig,
                        producerConfig: KafkaProducerConfig
                      )

case class KafkaConsumerConfig(
                                maxPollRecords: Int,
                                fetchMinBytes: Int,
                                maxPartitionFetchBytes: Int
                              )

case class KafkaProducerConfig(
                                batchSize: Int,
                                lingerMs: Int,
                                compressionType: String,
                                maxRequestSize: Int
                              )

object KafkaConfig {
  def load(rawConfig: Config): KafkaConfig = {
    KafkaConfig(
      bootstrapServers = rawConfig.getString("kafka.bootstrap-servers"),
      groupId = rawConfig.getString("kafka.group-id"),
      autoOffsetReset = rawConfig.getString("kafka.auto-offset-reset"),
      sessionTimeout = Duration.fromNanos(rawConfig.getDuration("kafka.session-timeout").toNanos),
      heartbeatInterval = Duration.fromNanos(rawConfig.getDuration("kafka.heartbeat-interval").toNanos),

      consumerConfig = KafkaConsumerConfig(
        maxPollRecords = rawConfig.getInt("kafka.consumer.max-poll-records"),
        fetchMinBytes = rawConfig.getInt("kafka.consumer.fetch-min-bytes"),
        maxPartitionFetchBytes = rawConfig.getInt("kafka.consumer.max-partition-fetch-bytes")
      ),

      producerConfig = KafkaProducerConfig(
        batchSize = rawConfig.getInt("kafka.producer.batch-size"),
        lingerMs = rawConfig.getInt("kafka.producer.linger-ms"),
        compressionType = rawConfig.getString("kafka.producer.compression-type"),
        maxRequestSize = rawConfig.getInt("kafka.producer.max-request-size")
      )
    )
  }
}

case class StorageConfig(
  basePath: String,
  checkpointLocation: String,
  inputFormat: String,
  outputFormat: String,
  compression: String,
  fraction: String,
  safeFraction: String,
  level: String = "MEMORY_AND_DISK"
)

object StorageConfig {
  def load(rawConfig: Config): StorageConfig = {
    StorageConfig(
      basePath = rawConfig.getString("storage.base-path"),
      checkpointLocation = rawConfig.getString("storage.paths.checkpoints"),
      inputFormat = rawConfig.getString("storage.formats.input"),
      outputFormat = rawConfig.getString("storage.formats.output"),
      compression = rawConfig.getString("storage.compression"),
      fraction = rawConfig.getString("spark.storage.fraction"),
      safeFraction = rawConfig.getString("spark.storage.safety-fraction"),
      level = rawConfig.getString("spark.storage.level")
    )
  }
}

case class MonitoringConfig(
  metricsEnabled: Boolean,
  healthCheckEnabled: Boolean,
  reportingInterval: Duration,
  uiEnabled: Boolean = true,
  uiPort: Option[Int] = None,
  eventLogEnabled: Boolean = false,
  eventLogDir: Option[String] = None
)

object MonitoringConfig {
  def load(rawConfig: Config): MonitoringConfig = {
    MonitoringConfig(
      metricsEnabled = rawConfig.getBoolean("monitoring.metrics.enabled"),
      healthCheckEnabled = rawConfig.getBoolean("monitoring.health-check.enabled"),
      reportingInterval = Duration.fromNanos(rawConfig.getDuration("monitoring.metrics.reporting-interval").toNanos),
      uiEnabled = if (rawConfig.hasPath("spark.ui.enabled")) rawConfig.getBoolean("spark.ui.enabled") else true,
      uiPort = if (rawConfig.hasPath("spark.ui.port")) Some(rawConfig.getInt("spark.ui.port")) else None,
      eventLogEnabled = if (rawConfig.hasPath("spark.eventLog.enabled")) rawConfig.getBoolean("spark.eventLog.enabled") else false,
      eventLogDir = if (rawConfig.hasPath("spark.eventLog.dir")) Some(rawConfig.getString("spark.eventLog.dir")) else None
    )
  }
}

case class DynamicAllocationConfig(
                                    enabled: Boolean,
                                    minExecutors: Int,
                                    maxExecutors: Int,
                                    initialExecutors: Int,
                                    targetExecutors: Option[Int] = None
                                  )

case class PerformanceConfig(
                              adaptiveQueryEnabled: Boolean,
                              adaptiveCoalescePartitions: Boolean,
                              adaptiveSkewJoin: Boolean,
                              shufflePartitions: Int,
                              serializer: String,
                              kryo: KryoConfig
                            )

case class KryoConfig(
                       enabled: Boolean,
                       bufferSize: String,
                       maxBufferSize: String,
                       registrationRequired: Boolean = false
                     )

case class NetworkingConfig(
                             timeout: String,
                             maxRetries: Int,
                             retryWait: String
                           )