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
  rangeValidation: Boolean,
  customValidation: Boolean,
  schemaValidation: Boolean = false,
  duplicateDetection: Boolean = false,
  dataProfiling: Boolean = false
)

case class DataQualityThresholds(
  errorRate: Double,
  completeness: Double,
  uniqueness: Double,
  schemaCompliance: Double = 0.95
)

object DataQualityConfig {
  def load(config: Config): DataQualityConfig = {
    val dqConfig = if (config.hasPath("data-quality")) {
      config.getConfig("data-quality")
    } else {
      // Default configuration if data-quality section is missing
      config.atPath("data-quality").getConfig("data-quality")
    }
    
    DataQualityConfig(
      enabled = getOrDefault(dqConfig, "enabled", true),
      failOnError = getOrDefault(dqConfig, "fail-on-error", false),
      rules = DataQualityRules(
        nullCheck = getOrDefault(dqConfig, "rules.null-check", true),
        formatValidation = getOrDefault(dqConfig, "rules.format-validation", true),
        rangeValidation = getOrDefault(dqConfig, "rules.range-validation", true),
        customValidation = getOrDefault(dqConfig, "rules.custom-validation", true),
        schemaValidation = getOrDefault(dqConfig, "rules.schema-validation", false),
        duplicateDetection = getOrDefault(dqConfig, "rules.duplicate-detection", false),
        dataProfiling = getOrDefault(dqConfig, "rules.data-profiling", false)
      ),
      thresholds = DataQualityThresholds(
        errorRate = getOrDefault(dqConfig, "thresholds.error-rate", 0.05),
        completeness = getOrDefault(dqConfig, "thresholds.completeness", 0.95),
        uniqueness = getOrDefault(dqConfig, "thresholds.uniqueness", 0.98),
        schemaCompliance = getOrDefault(dqConfig, "thresholds.schema-compliance", 0.95)
      )
    )
  }
  
  private def getOrDefault[T](config: Config, path: String, defaultValue: T): T = {
    if (config.hasPath(path)) {
      defaultValue match {
        case _: Boolean => config.getBoolean(path).asInstanceOf[T]
        case _: Double => config.getDouble(path).asInstanceOf[T]
        case _: Int => config.getInt(path).asInstanceOf[T]
        case _: String => config.getString(path).asInstanceOf[T]
        case _ => defaultValue
      }
    } else {
      defaultValue
    }
  }
}