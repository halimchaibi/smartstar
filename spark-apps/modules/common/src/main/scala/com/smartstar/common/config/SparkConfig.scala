package com.smartstar.common.config

import com.typesafe.config.Config

case class SparkConfig(
  master: String,
  executorMemory: String,
  executorCores: Int,
  dynamicAllocation: Boolean,
  maxExecutors: Int,
  minExecutors: Int
)

object SparkConfig {
  def load(config: Config): SparkConfig = SparkConfig(
    master = config.getString("master"),
    executorMemory = config.getString("executor.memory"),
    executorCores = config.getInt("executor.cores"),
    dynamicAllocation = config.getBoolean("dynamic-allocation.enabled"),
    maxExecutors = config.getInt("dynamic-allocation.max-executors"),
    minExecutors = config.getInt("dynamic-allocation.min-executors")
  )
}
