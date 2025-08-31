package com.smartstar.common.utils

import org.slf4j.{Logger, LoggerFactory}

trait LoggingUtils {
  @transient lazy val logger: Logger = LoggerFactory.getLogger(getClass)
  
  def logInfo(message: String): Unit = logger.info(message)
  def logWarn(message: String): Unit = logger.warn(message)
  def logError(message: String, throwable: Throwable = null): Unit = {
    if (throwable != null) logger.error(message, throwable)
    else logger.error(message)
  }
  def logDebug(message: String): Unit = logger.debug(message)
  
  def logExecutionTime[T](operationName: String)(operation: => T): T = {
    val startTime = System.currentTimeMillis()
    logInfo(s"Starting operation: $operationName")
    
    try {
      val result = operation
      val endTime = System.currentTimeMillis()
      logInfo(s"Completed operation: $operationName in ${endTime - startTime}ms")
      result
    } catch {
      case ex: Exception =>
        val endTime = System.currentTimeMillis()
        logError(s"Failed operation: $operationName after ${endTime - startTime}ms", ex)
        throw ex
    }
  }
}
