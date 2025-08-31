// ===== Streaming-Specific Environment-Aware Trait =====
package com.smartstar.common.traits

import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.streaming.StreamingQuery
import com.smartstar.common.config.{Environment, SparkSessionConfig}
import com.smartstar.common.session.EnvironmentSparkSessionFactory

trait EnvironmentAwareStreamingJob extends EnvironmentAwareSparkJob {
  
  def checkpointLocation: String
  
  override protected lazy val spark: SparkSession = createStreamingSession()
  
  private def createStreamingSession(): SparkSession = {
    logInfo(s"Creating streaming Spark session for $appName in ${environment.name}")
    
    val sparkConfig = SparkSessionConfig.load(config.rawConfig, environment)
    
    val streamingConfigs = Map(
      "spark.sql.streaming.checkpointLocation" -> checkpointLocation,
      "spark.sql.streaming.forceDeleteTempCheckpointLocation" -> "true",
      "spark.sql.adaptive.enabled" -> "false" // Disable AQE for streaming
    ) ++ getEnvironmentStreamingConfigs
    
    EnvironmentSparkSessionFactory.createSession(
      appName = appName,
      config = sparkConfig,
      environment = environment,
      additionalConfigs = streamingConfigs ++ additionalSparkConfigs
    )
  }
  
  private def getEnvironmentStreamingConfigs: Map[String, String] = {
    environment match {
      case Environment.Development =>
        Map(
          "spark.sql.streaming.ui.enabled" -> "true",
          "spark.sql.streaming.ui.retainedBatches" -> "100"
        )
      case Environment.Production =>
        Map(
          "spark.sql.streaming.ui.retainedBatches" -> "1000",
          "spark.sql.streaming.stopGracefullyOnShutdown" -> "true"
        )
      case _ =>
        Map.empty
    }
  }
  
  def runStreaming(args: Array[String]): StreamingQuery
  
  override def run(args: Array[String]): Unit = {
    val query = runStreaming(args)
    query.awaitTermination()
  }
}