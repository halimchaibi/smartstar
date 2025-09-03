package com.smartstar.common.config

import com.typesafe.config.Config

case class DataQualityConfig(
  enabled: Boolean,
  failOnError: Boolean,
  rules: DataQualityRules,
  thresholds: DataQualityThresholds
)

case class DataQualityRules(
  nullCheck: Boolean,
  formatValidation: Boolean,
  uniquenessCheck: Boolean
)

case class DataQualityThresholds(
  errorRate: Double,
  completeness: Double,
  uniqueness: Double
)

object DataQualityConfig {
  def load(config: Config): DataQualityConfig = {
    if (config.hasPath("data-quality")) {
      val dqConfig = config.getConfig("data-quality")
      DataQualityConfig(
        enabled = if (dqConfig.hasPath("enabled")) dqConfig.getBoolean("enabled") else true,
        failOnError = if (dqConfig.hasPath("fail-on-error")) dqConfig.getBoolean("fail-on-error") else false,
        rules = loadRules(dqConfig),
        thresholds = loadThresholds(dqConfig)
      )
    } else {
      // Default configuration when data-quality section is missing
      DataQualityConfig(
        enabled = true,
        failOnError = false,
        rules = DataQualityRules(
          nullCheck = true,
          formatValidation = true,
          uniquenessCheck = false
        ),
        thresholds = DataQualityThresholds(
          errorRate = 0.05,
          completeness = 0.95,
          uniqueness = 0.95
        )
      )
    }
  }

  private def loadRules(config: Config): DataQualityRules = {
    if (config.hasPath("rules")) {
      val rulesConfig = config.getConfig("rules")
      DataQualityRules(
        nullCheck = if (rulesConfig.hasPath("null-check")) rulesConfig.getBoolean("null-check") else true,
        formatValidation = if (rulesConfig.hasPath("format-validation")) rulesConfig.getBoolean("format-validation") else true,
        uniquenessCheck = if (rulesConfig.hasPath("uniqueness-check")) rulesConfig.getBoolean("uniqueness-check") else false
      )
    } else {
      DataQualityRules(
        nullCheck = true,
        formatValidation = true,
        uniquenessCheck = false
      )
    }
  }

  private def loadThresholds(config: Config): DataQualityThresholds = {
    if (config.hasPath("thresholds")) {
      val thresholdsConfig = config.getConfig("thresholds")
      DataQualityThresholds(
        errorRate = if (thresholdsConfig.hasPath("error-rate")) thresholdsConfig.getDouble("error-rate") else 0.05,
        completeness = if (thresholdsConfig.hasPath("completeness")) thresholdsConfig.getDouble("completeness") else 0.95,
        uniqueness = if (thresholdsConfig.hasPath("uniqueness")) thresholdsConfig.getDouble("uniqueness") else 0.95
      )
    } else {
      DataQualityThresholds(
        errorRate = 0.05,
        completeness = 0.95,
        uniqueness = 0.95
      )
    }
  }
}