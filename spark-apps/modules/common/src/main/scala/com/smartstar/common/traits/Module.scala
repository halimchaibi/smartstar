package com.smartstar.common.traits

sealed trait Module {
  def name: String
}

object Module {
  case object Core extends Module {
    override def name: String = "core"
  }

  case object Analytics extends Module {
    override def name: String = "analytics"
  }

  case object Ingestion extends Module {
    override def name: String = "ingestion"
  }

  case object Reporting extends Module {
    override def name: String = "reporting"
  }

  case object Normalization extends Module {
    override def name: String = "normalization"
  }

  def fromString(module: String): Option[Module] = module.toLowerCase match {
    case "core"          => Some(Core)
    case "analytics"     => Some(Analytics)
    case "ingestion"     => Some(Ingestion)
    case "reporting"     => Some(Reporting)
    case "normalization" => Some(Reporting)
    case _           => None
  }

  def detect(): Option[Module] = {
    val moduleString = Option(System.getProperty("MODULE_NAME"))
      .getOrElse("core")

    try {
      fromString(moduleString)
    } catch {
      case _: IllegalArgumentException => Some(Core)
    }
  }
  val all: List[Module] = List(Core, Analytics, Ingestion, Reporting)
}
