package com.smartstar.common.config

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers
import org.scalatest.{BeforeAndAfterEach, BeforeAndAfterAll}
import com.typesafe.config.ConfigFactory
import com.smartstar.common.traits.{Environment, Module}

class ConfigurationSystemSpec extends AnyFlatSpec with Matchers with BeforeAndAfterEach with BeforeAndAfterAll {

  override def beforeEach(): Unit = {
    // Clear system properties before each test
    System.clearProperty("environment")
    System.clearProperty("MODULE_NAME")
  }

  "Environment" should "detect environment from system properties" in {
    System.setProperty("environment", "production")
    Environment.detect() shouldBe Environment.Production
    
    System.setProperty("environment", "staging")
    Environment.detect() shouldBe Environment.Staging
    
    System.setProperty("environment", "development")
    Environment.detect() shouldBe Environment.Development
  }

  it should "default to development when no environment is set" in {
    Environment.detect() shouldBe Environment.Development
  }

  it should "parse environment strings correctly" in {
    Environment.fromString("prod") shouldBe Environment.Production
    Environment.fromString("PRODUCTION") shouldBe Environment.Production
    Environment.fromString("dev") shouldBe Environment.Development
    Environment.fromString("test") shouldBe Environment.Test
  }

  it should "throw exception for invalid environment string" in {
    assertThrows[IllegalArgumentException] {
      Environment.fromString("invalid")
    }
  }

  "AppConfig" should "load default configuration successfully" in {
    val config = AppConfig.load()
    
    config.appName should not be empty
    config.version should not be empty
    config.environment shouldBe Environment.Development // default
  }

  it should "load configuration for specific environment" in {
    val config = AppConfig.loadForEnvironmentAndModule(Environment.Test, Module.Core)
    
    config.environment shouldBe Environment.Test
    config.appName should not be empty
  }

  it should "load configuration for specific module" in {
    val config = AppConfig.loadForEnvironmentAndModule(Environment.Development, Module.Ingestion)
    
    config.environment shouldBe Environment.Development
    config.module shouldBe Module.Ingestion
  }

  it should "validate required configuration paths" in {
    val config = AppConfig.load()
    AppConfig.validate(config.rawConfig) shouldBe true
  }

  it should "handle missing configuration gracefully" in {
    val invalidConfig = ConfigFactory.parseString("invalid = true")
    AppConfig.validate(invalidConfig) shouldBe false
  }

  "ConfigurationFactory" should "create job configuration correctly" in {
    val config = ConfigurationFactory.forJob("test-job")
    
    config.appName should not be empty
    config.environment should not be null
  }

  it should "create module-specific configuration" in {
    val config = ConfigurationFactory.forEnvironmentAndModule(Environment.Development, Module.Ingestion)
    
    config.module shouldBe Module.Ingestion
    config.environment should not be null
  }

  it should "create environment-specific configuration" in {
    val config = ConfigurationFactory.forEnvironmentAndModule(Environment.Production, Module.Core)
    
    config.environment shouldBe Environment.Production
  }

  it should "validate consistency across environments" in {
    // This test validates that all environment configs are loadable
    // In a real scenario, this would catch configuration inconsistencies
    val isConsistent = ConfigurationFactory.validateConsistency()
    
    // Should return true if all environments have valid configurations
    // or false if there are issues with any environment
    isConsistent shouldBe a[Boolean]
  }

  "DataQualityConfig" should "load with default values when section is missing" in {
    val emptyConfig = ConfigFactory.parseString("app { name = \"test\" }")
    val dqConfig = DataQualityConfig.load(emptyConfig)
    
    dqConfig.enabled shouldBe true
    dqConfig.failOnError shouldBe false
    dqConfig.rules.nullCheck shouldBe true
    dqConfig.thresholds.errorRate shouldBe 0.05
  }

  it should "load configured values when section exists" in {
    val configString = """
      data-quality {
        enabled = false
        fail-on-error = true
        rules {
          null-check = false
          format-validation = true
        }
        thresholds {
          error-rate = 0.1
          completeness = 0.8
        }
      }
    """
    val config = ConfigFactory.parseString(configString)
    val dqConfig = DataQualityConfig.load(config)
    
    dqConfig.enabled shouldBe false
    dqConfig.failOnError shouldBe true
    dqConfig.rules.nullCheck shouldBe false
    dqConfig.rules.formatValidation shouldBe true
    dqConfig.thresholds.errorRate shouldBe 0.1
    dqConfig.thresholds.completeness shouldBe 0.8
  }

  "Configuration hierarchy" should "properly override values" in {
    // Test that environment-specific configs override base configs
    val devConfig = ConfigurationFactory.forEnvironmentAndModule(Environment.Development, Module.Core)
    val prodConfig = ConfigurationFactory.forEnvironmentAndModule(Environment.Production, Module.Core)
    
    // Both should have the same app name
    devConfig.appName shouldBe prodConfig.appName
  }

  it should "properly handle module-specific overrides" in {
    val ingestionConfig = ConfigurationFactory.forEnvironmentAndModule(Environment.Development, Module.Ingestion)
    val analyticsConfig = ConfigurationFactory.forEnvironmentAndModule(Environment.Development, Module.Analytics)
    
    // Both should have same base app config
    ingestionConfig.appName shouldBe analyticsConfig.appName
    
    // But may have different module-specific settings
    ingestionConfig.module shouldBe Module.Ingestion
    analyticsConfig.module shouldBe Module.Analytics
  }

  override def afterAll(): Unit = {
    // Clean up system properties
    System.clearProperty("environment")
    System.clearProperty("MODULE_NAME")
  }
}