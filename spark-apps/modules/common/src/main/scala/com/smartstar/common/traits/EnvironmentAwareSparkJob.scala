package com.smartstar.common.traits

import com.smartstar.common.config.AppConfig
import com.smartstar.common.session.EnvironmentSparkSessionFactory
import com.smartstar.common.utils.LoggingUtils
import org.apache.spark.sql.SparkSession

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
    EnvironmentSparkSessionFactory.createSession(config, additionalSparkConfigs)
  }

  def run(args: Array[String]): Unit

  def close(): Unit =
    if (spark != null) {
      logInfo(s"Stopping Spark session for $appName")
      logAllSparkConfigs()
      spark.stop()
    }

  def checkJarLoading(): Unit = {
    logInfo("=" * 50)
    logInfo("COMPREHENSIVE JAR LOADING CHECK")
    logInfo("=" * 50)

    // 1. Check SparkContext JARs
    logInfo("1. SparkContext JARs:")
    val contextJars = spark.sparkContext.jars
    contextJars.zipWithIndex.foreach { case (jar, index) =>
      val isIceberg = jar.toLowerCase.contains("iceberg")
      val marker = if (isIceberg) "✅" else "  "
      logInfo(s"   $marker [$index] $jar")
    }

    // 2. Check ClassPath
    logInfo("\n2. Java ClassPath (Iceberg entries only):")
    val classpath = System.getProperty("java.class.path")
    val icebergClasspathEntries = classpath.split(java.io.File.pathSeparator)
      .filter(_.toLowerCase.contains("iceberg"))

    if (icebergClasspathEntries.nonEmpty) {
      icebergClasspathEntries.foreach(entry => logInfo(s"   ✅ $entry"))
    } else {
      logInfo("   ❌ No Iceberg entries found in classpath")
    }

    // 3. Check Class Loading
    logInfo("\n3. Class Loading Test:")
    val testClasses = Map(
      "SparkCatalog" -> "org.apache.iceberg.spark.SparkCatalog",
      "Extensions" -> "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions",
      "Table" -> "org.apache.iceberg.Table"
    )

    testClasses.foreach { case (name, className) =>
      try {
        val clazz = Class.forName(className)
        val location = Option(clazz.getProtectionDomain.getCodeSource)
          .map(_.getLocation.toString)
          .getOrElse("Unknown location")
        logInfo(s"   ✅ $name: $className")
        logInfo(s"      Location: $location")
      } catch {
        case _: ClassNotFoundException =>
          logInfo(s"   ❌ $name: $className - NOT FOUND")
        case ex: Exception =>
          logInfo(s"   ❌ $name: $className - ERROR: ${ex.getMessage}")
      }
    }

    // 4. Check Spark SQL Catalog
    logInfo("\n4. Spark SQL Catalog Test:")
    try {
      spark.sql("SHOW CATALOGS").collect().foreach { row =>
        logInfo(s"   Catalog: ${row.getString(0)}")
      }
      logInfo("   ✅ SHOW CATALOGS worked")
    } catch {
      case ex: Exception =>
        logInfo(s"   ❌ SHOW CATALOGS failed: ${ex.getMessage}")
    }

    logInfo("=" * 50)
  }

  private def logAllSparkConfigs(): Unit = {
    logInfo("=== Applied Spark Configuration ===")
    try {
      val allConfigs = spark.conf.getAll
      val sortedConfigs = allConfigs.toSeq.sortBy(_._1)

      logInfo(s"Total configurations: ${sortedConfigs.size}")

      sortedConfigs.foreach { case (key, value) =>
        // Mask sensitive values
        val maskedValue = if (key.toLowerCase.contains("password") ||
          key.toLowerCase.contains("secret") ||
          key.toLowerCase.contains("key") ||
          key.toLowerCase.contains("token")) {
          "***MASKED***"
        } else {
          value
        }
        logInfo(s"$key = $maskedValue")
      }
    } catch {
      case ex: Exception =>
        logError(s"Failed to retrieve Spark configurations: ${ex.getMessage}", ex)
    }
    logInfo("=== End Spark Configuration ===")
  }
}
