package com.smartstar.common.models

import java.sql.Timestamp

case class JobResult(
  jobName: String,
  status: JobStatus,
  startTime: Timestamp,
  endTime: Option[Timestamp] = None,
  recordsProcessed: Long = 0L,
  errorMessage: Option[String] = None,
  metrics: Map[String, Any] = Map.empty
) {
  def duration: Option[Long] = endTime.map(_.getTime - startTime.getTime)
  def isSuccess: Boolean = status == JobStatus.Success
  def isFailure: Boolean = status == JobStatus.Failed
}

sealed trait JobStatus

object JobStatus {
  case object Running extends JobStatus
  case object Success extends JobStatus
  case object Failed extends JobStatus
  case object Cancelled extends JobStatus
}
