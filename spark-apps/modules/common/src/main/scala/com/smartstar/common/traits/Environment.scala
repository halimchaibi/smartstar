package com.smartstar.common.traits

sealed trait Environment {
  def name: String
  def configPath: String = s"environments/$name.conf"
  def isProduction: Boolean = false
  def isDevelopment: Boolean = false
  def isStaging: Boolean = false
  def isTest: Boolean = false
}

object Environment {
  case object Development extends Environment {
    override def name: String = "development"
    override def isDevelopment: Boolean = true
  }

  case object Staging extends Environment {
    override def name: String = "staging"
    override def isStaging: Boolean = true
  }

  case object Production extends Environment {
    override def name: String = "production"
    override def isProduction: Boolean = true
  }

  case object Test extends Environment {
    override def name: String = "test"
    override def isTest: Boolean = true
  }

  /**
   * Parse environment from string
   */
  def fromString(env: String): Environment = env.toLowerCase match {
    case "development" | "dev" | "local" => Development
    case "staging" | "stage"             => Staging
    case "production" | "prod"           => Production
    case "test"                          => Test
    case _ => throw new IllegalArgumentException(s"Unknown environment: $env")
  }

  /**
   * Detect environment from system properties and environment variables
   */
  def detect(): Environment = {
    val envString = Option(System.getProperty("environment"))
      .orElse(Option(System.getProperty("spark.env")))
      .orElse(Option(System.getenv("ENVIRONMENT")))
      .orElse(Option(System.getenv("ENV")))
      .orElse(Option(System.getenv("SPARK_ENV")))
      .getOrElse("development")

    try {
      fromString(envString)
    } catch {
      case _: IllegalArgumentException => Development // Fallback to development for invalid values
    }
  }

  /**
   * Get current environment (deprecated, use detect() instead)
   */
  @deprecated("Use detect() instead", "1.0.0")
  def current: Environment = detect()

  val all: List[Environment] = List(Development, Staging, Production, Test)
}
