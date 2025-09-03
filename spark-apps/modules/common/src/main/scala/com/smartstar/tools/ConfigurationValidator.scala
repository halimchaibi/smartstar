package com.smartstar.tools

import com.smartstar.common.config.ConfigurationFactory
import com.smartstar.common.traits.Environment
import com.smartstar.common.traits.Environment.Development
import com.smartstar.common.traits.Module
import com.smartstar.common.utils.LoggingUtils

/**
 * Configuration validation tool for SmartStar project.
 * This tool validates configuration consistency across all environments and modules.
 */
object ConfigurationValidator extends LoggingUtils {

  def main(args: Array[String]): Unit = {
    logInfo("Starting SmartStar Configuration Validation")
    logInfo("=" * 50)

    val results = validateAllConfigurations()
    
    printValidationResults(results)
    
    val overallSuccess = results.values.forall(_.isSuccess)
    
    if (overallSuccess) {
      logInfo("✅ All configurations are valid and consistent!")
      System.exit(0)
    } else {
      logError("❌ Configuration validation failed. Please check the errors above.")
      System.exit(1)
    }
  }

  private def validateAllConfigurations(): Map[String, ValidationResult] = {
    val results = scala.collection.mutable.Map[String, ValidationResult]()

    // Test environment detection
    results += "Environment Detection" -> validateEnvironmentDetection()

    // Test each environment
    Environment.all.foreach { env =>
      results += s"Environment: ${env.name}" -> validateEnvironment(env)
    }

    // Test each module in development environment
    val modules = Module.all
    modules.foreach { module =>
      results += s"Module: $module" -> validateModule(module)
    }

    // Test cross-environment consistency
    results += "Cross-Environment Consistency" -> validateConsistency()

    results.toMap
  }

  private def validateEnvironmentDetection(): ValidationResult = {
    try {
      val env = Environment.detect()
      ValidationResult(
        isSuccess = true,
        message = s"Successfully detected environment: ${env.name}",
        details = Seq(s"Environment: ${env.name}")
      )
    } catch {
      case ex: Exception =>
        ValidationResult(
          isSuccess = false,
          message = s"Failed to detect environment: ${ex.getMessage}",
          details = Seq(ex.toString)
        )
    }
  }

  private def validateEnvironment(environment: Environment): ValidationResult = {
    try {
      //TODO:
      val config = ConfigurationFactory.forEnvironment(environment, Module.Core)
      
      val details = Seq(
        s"App Name: ${config.appName}",
        s"Version: ${config.version}",
      )

      ValidationResult(
        isSuccess = true,
        message = s"Environment ${environment.name} configuration is valid",
        details = details
      )
    } catch {
      case ex: Exception =>
        ValidationResult(
          isSuccess = false,
          message = s"Failed to load configuration for environment ${environment.name}: ${ex.getMessage}",
          details = Seq(ex.toString)
        )
    }
  }

  private def validateModule(module: Module): ValidationResult = {
    try {
      //TODO:
      val config = ConfigurationFactory.forModule(Development, module)
      
      val details = Seq(
        s"Module: ${config.module.name}",
        s"Environment: ${config.environment.name}",
        s"App Name: ${config.appName}",
        s"Configuration loaded successfully"
      )

      ValidationResult(
        isSuccess = true,
        message = s"Module $module.name configuration is valid",
        details = details
      )
    } catch {
      case ex: Exception =>
        ValidationResult(
          isSuccess = false,
          message = s"Failed to load configuration for module $module.name: ${ex.getMessage}",
          details = Seq(ex.toString)
        )
    }
  }

  private def validateConsistency(): ValidationResult = {
    try {
      val isConsistent = ConfigurationFactory.validateConsistency()
      
      if (isConsistent) {
        ValidationResult(
          isSuccess = true,
          message = "Configuration consistency validation passed",
          details = Seq("All environments have consistent and valid configurations")
        )
      } else {
        ValidationResult(
          isSuccess = false,
          message = "Configuration consistency validation failed",
          details = Seq("Some environments have inconsistent or invalid configurations")
        )
      }
    } catch {
      case ex: Exception =>
        ValidationResult(
          isSuccess = false,
          message = s"Failed to validate configuration consistency: ${ex.getMessage}",
          details = Seq(ex.toString)
        )
    }
  }

  private def printValidationResults(results: Map[String, ValidationResult]): Unit = {
    logInfo("\nValidation Results:")
    logInfo("-" * 30)

    results.foreach { case (testName, result) =>
      val status = if (result.isSuccess) "✅ PASS" else "❌ FAIL"
      logInfo(s"$status $testName")
      logInfo(s"     ${result.message}")
      
      if (result.details.nonEmpty) {
        result.details.foreach { detail =>
          logInfo(s"     - $detail")
        }
      }
      logInfo("")
    }

    val (passed, failed) = results.values.partition(_.isSuccess)
    logInfo(s"Summary: ${passed.size} passed, ${failed.size} failed")
  }

  case class ValidationResult(
    isSuccess: Boolean,
    message: String,
    details: Seq[String] = Seq.empty
  )
}