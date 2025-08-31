package com.smartstar.common.traits

import com.smartstar.common.config.AppConfig

trait ConfigurableJob {
  def config: AppConfig
  
  def validateConfig(): Unit = {
    // Basic config validation
    require(config.appName.nonEmpty, "Application name cannot be empty")
  }
}
