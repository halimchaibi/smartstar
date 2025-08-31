package com.smartstar.common.config

import com.typesafe.config.Config

import scala.concurrent.duration.Duration

case class DatabaseConfig(
                           driver: String,
                           host: String,
                           port: Int,
                           name: String,
                           username: String,
                           password: String,
                           ssl: Boolean,
                           connectionPoolSize: Int,
                           connectionTimeout: Duration
                         )

object DatabaseConfig {
  def load(rawConfig: Config): DatabaseConfig = {
    DatabaseConfig(
      driver = rawConfig.getString("database.driver"),
      host = rawConfig.getString("database.host"),
      port = rawConfig.getInt("database.port"),
      name = rawConfig.getString("database.name"),
      username = rawConfig.getString("database.username"),
      password = rawConfig.getString("database.password"),
      ssl = rawConfig.getBoolean("database.ssl"),
      connectionPoolSize = rawConfig.getInt("database.connection-pool-size"),
      connectionTimeout = Duration.fromNanos(rawConfig.getDuration("database.connection-timeout").toNanos)
    )
  }
}
