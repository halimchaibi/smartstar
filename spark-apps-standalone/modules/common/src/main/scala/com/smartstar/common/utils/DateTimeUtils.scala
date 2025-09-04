package com.smartstar.common.utils

import java.sql.Timestamp
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

object DateTimeUtils {
  
  val DEFAULT_FORMAT: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")
  val ISO_FORMAT: DateTimeFormatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME
  
  def getCurrentTimestamp: Timestamp = Timestamp.valueOf(LocalDateTime.now())
  
  def parseTimestamp(dateString: String, formatter: DateTimeFormatter = DEFAULT_FORMAT): Timestamp = {
    val localDateTime = LocalDateTime.parse(dateString, formatter)
    Timestamp.valueOf(localDateTime)
  }
  
  def formatTimestamp(timestamp: Timestamp, formatter: DateTimeFormatter = DEFAULT_FORMAT): String = {
    timestamp.toLocalDateTime.format(formatter)
  }
  
  def addDays(timestamp: Timestamp, days: Long): Timestamp = {
    val localDateTime = timestamp.toLocalDateTime.plusDays(days)
    Timestamp.valueOf(localDateTime)
  }
  
  def addHours(timestamp: Timestamp, hours: Long): Timestamp = {
    val localDateTime = timestamp.toLocalDateTime.plusHours(hours)
    Timestamp.valueOf(localDateTime)
  }
}
