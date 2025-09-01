package com.smartstar.common.traits

import org.apache.spark.sql.SparkSession
import com.smartstar.common.config.{AppConfig, Environment, SparkSessionConfig}
import com.smartstar.common.session.EnvironmentSparkSessionFactory
import com.smartstar.common.utils.LoggingUtils

trait EnvironmentAwareSparkJob extends LoggingUtils {
  
  def appName: String
  def config: AppConfig
  
  // Allow jobs to override environment (useful for testing)
  def environment: Environment = Environment.detect()
  
  // Allow jobs to provide additional configurations
  def additionalSparkConfigs: Map[String, String] = Map.empty
  
  // Allow jobs to customize session creation
  def customizeSessionBuilder(builder: SparkSession.Builder): SparkSession.Builder = builder
  
  protected lazy val spark: SparkSession = createEnvironmentAwareSession()
  
  private def createEnvironmentAwareSession(): SparkSession = {
    logInfo(s"Creating environment-aware Spark session for $appName in ${environment.name}")
    
    val sparkConfig = SparkSessionConfig.load(config.rawConfig, environment)
    
    EnvironmentSparkSessionFactory.createSession(
      appName = appName,
      config = sparkConfig,
      environment = environment,
      additionalConfigs = additionalSparkConfigs
    )
  }
  
  def run(args: Array[String]): Unit
  
  def close(): Unit = {
    if (spark != null) {
      logInfo(s"Stopping Spark session for $appName")
      spark.stop()
    }
  }
  
  // Utility methods for environment-specific behavior
  protected def whenDevelopment[T](block: => T): Option[T] = {
    if (environment.isDevelopment) Some(block) else None
  }
  
  protected def whenStaging[T](block: => T): Option[T] = {
    if (environment.isStaging) Some(block) else None
  }
  
  protected def whenProduction[T](block: => T): Option[T] = {
    if (environment.isProduction) Some(block) else None
  }
}