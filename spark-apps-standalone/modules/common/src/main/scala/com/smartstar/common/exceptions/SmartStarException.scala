package com.smartstar.common.exceptions

class SmartStarException(message: String, cause: Throwable = null)
    extends RuntimeException(message, cause)

class DataQualityException(message: String, cause: Throwable = null)
    extends SmartStarException(message, cause)

class ConfigurationException(message: String, cause: Throwable = null)
    extends SmartStarException(message, cause)

class DataIngestionException(message: String, cause: Throwable = null)
    extends SmartStarException(message, cause)

class DataTransformationException(message: String, cause: Throwable = null)
    extends SmartStarException(message, cause)
