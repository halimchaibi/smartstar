package com.smartstar.common.models

case class DataSource(
  name: String,
  sourceType: SourceType,
  connectionString: String,
  schema: Option[String] = None,
  tableName: Option[String] = None
)

case class DataTarget(
  name: String,
  targetType: TargetType,
  connectionString: String,
  schema: Option[String] = None,
  tableName: Option[String] = None,
  writeMode: WriteMode = WriteMode.Append
)

sealed trait SourceType

object SourceType {
  case object Database extends SourceType
  case object File extends SourceType
  case object Stream extends SourceType
  case object API extends SourceType
}

sealed trait TargetType

object TargetType {
  case object Database extends TargetType
  case object File extends TargetType
  case object Stream extends TargetType
}

sealed trait WriteMode

object WriteMode {
  case object Append extends WriteMode
  case object Overwrite extends WriteMode
  case object Merge extends WriteMode
}
