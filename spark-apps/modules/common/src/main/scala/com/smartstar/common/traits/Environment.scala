package com.smartstar.common.config

sealed trait Environment {
  def name: String
  def isProduction: Boolean = false
  def isDevelopment: Boolean = false
  def isStaging: Boolean = false
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
  }
  
  def fromString(env: String): Environment = env.toLowerCase match {
    case "development" | "dev" | "local" => Development
    case "staging" | "stage" => Staging
    case "production" | "prod" => Production
    case "test" => Test
    case _ => Development // Default fallback
  }
  
  def current: Environment = {
    val envVar = sys.env.getOrElse("SPARK_ENV", 
                 sys.env.getOrElse("ENVIRONMENT", 
                 sys.props.getOrElse("environment", "development")))
    fromString(envVar)
  }
}