package com.smartstar.common.config

import com.typesafe.config.Config

case class DatabaseConfig(
  url: String,
  username: String,
  password: String,
  driver: String,
  connectionPoolSize: Int
)

object DatabaseConfig {
  def load(config: Config): DatabaseConfig = DatabaseConfig(
    url = config.getString("url"),
    username = config.getString("username"),
    password = config.getString("password"),
    driver = config.getString("driver"),
    connectionPoolSize = config.getInt("connection-pool-size")
  )
}
