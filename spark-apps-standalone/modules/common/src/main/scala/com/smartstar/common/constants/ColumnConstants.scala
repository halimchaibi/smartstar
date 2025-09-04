package com.smartstar.common.constants

object ColumnConstants {
  // Standard audit columns
  val CREATED_AT = "created_at"
  val UPDATED_AT = "updated_at"
  val CREATED_BY = "created_by"
  val UPDATED_BY = "updated_by"
  val VERSION = "version"
  val IS_DELETED = "is_deleted"

  // Data quality columns
  val DATA_QUALITY_SCORE = "data_quality_score"
  val VALIDATION_STATUS = "validation_status"
  val ERROR_MESSAGE = "error_message"
  val SOURCE_SYSTEM = "source_system"

  // Processing metadata
  val PROCESSING_DATE = "processing_date"
  val JOB_ID = "job_id"
  val BATCH_ID = "batch_id"
  val PARTITION_KEY = "partition_key"
}
