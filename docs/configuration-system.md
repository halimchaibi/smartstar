# SmartStar Configuration System

## Overview

The SmartStar configuration system provides a consistent, hierarchical, and environment-aware approach to managing configuration across all modules and environments. It uses the Typesafe Config library (HOCON format) with a structured hierarchy that supports:

- Environment-specific configurations (development, staging, production, test)
- Module-specific configurations (ingestion, normalization, analytics)
- Automatic environment detection
- Configuration validation
- Fallback mechanisms

## Configuration Hierarchy

Configuration is loaded in the following order, with later configurations overriding earlier ones:

1. **Base Application Configuration**: `modules/common/src/main/resources/application.conf`
2. **Common Shared Configuration**: `config/common.conf`
3. **Environment-Specific Configuration**: `config/environments/{environment}.conf`
4. **Module-Specific Configuration**: `config/modules/{module}.conf`
5. **Environment Variables**: System properties and environment variables

## Directory Structure

```
spark-apps/
├── config/
│   ├── common.conf                     # Shared configuration across all modules
│   ├── environments/
│   │   ├── development.conf            # Development environment settings
│   │   ├── staging.conf                # Staging environment settings
│   │   ├── production.conf             # Production environment settings
│   │   └── test.conf                   # Test environment settings
│   └── modules/
│       ├── ingestion.conf              # Ingestion module specific settings
│       ├── normalization.conf          # Normalization module specific settings
│       └── analytics.conf              # Analytics module specific settings
└── modules/common/src/main/resources/
    └── application.conf                # Base configuration with includes
```

## Usage Patterns

### 1. Using ConfigurationFactory (Recommended)

The `ConfigurationFactory` provides the most consistent way to load configurations:

```scala
import com.smartstar.common.config.ConfigurationFactory

// For a job with automatic environment detection
val config = ConfigurationFactory.forJob("my-job")

// For a specific module (automatically detects environment)
val config = ConfigurationFactory.forModule("ingestion")

// For a specific environment
val config = ConfigurationFactory.forEnvironment(Environment.Production)

// For a specific environment and module combination
val config = ConfigurationFactory.forEnvironmentAndModule(Environment.Production, "ingestion")

// For testing with minimal resources
val config = ConfigurationFactory.forTesting("my-test")
```

### 2. Using AppConfig Directly

```scala
import com.smartstar.common.config.{AppConfig, Environment}

// Load with automatic environment detection
val config = AppConfig.load()

// Load for specific environment
val config = AppConfig.loadForEnvironment(Environment.Production)

// Load for specific environment and module
val config = AppConfig.loadForEnvironmentAndModule(Environment.Staging, Some("analytics"))
```

### 3. In Job Classes

```scala
import com.smartstar.common.config.ConfigurationFactory
import com.smartstar.common.traits.{SparkJob, ConfigurableJob}

class MyIngestionJob extends SparkJob with ConfigurableJob {
  override def appName: String = "My-Ingestion-Job"
  override def config: AppConfig = ConfigurationFactory.forModule("ingestion")
  
  override def run(args: Array[String]): Unit = {
    validateConfig() // Validates configuration including environment-specific rules
    
    // Access configuration
    val inputPath = getConfigValue("ingestion.input-path")
    val batchSize = getRequiredConfigValue("ingestion.batch-size")
    
    // Use Spark configuration
    val spark = createSparkSession()
    // ... job logic
  }
}
```

## Environment Detection

The system automatically detects the environment from the following sources (in order of priority):

1. System property: `environment`
2. System property: `spark.env`
3. Environment variable: `ENVIRONMENT`
4. Environment variable: `ENV`
5. Environment variable: `SPARK_ENV`
6. Default: `development`

## Module Detection

Modules are detected from:

1. Environment variable: `MODULE_NAME`
2. System property: `MODULE_NAME`
3. Explicitly specified in code

## Configuration Sections

### App Configuration
```hocon
app {
  name = "smartstar"
  version = "1.0.0"
  description = "SmartStar Data Platform"
  organization = "SmartStar Team"
}
```

### Spark Configuration
```hocon
spark {
  master = "local[*]"
  app-name = ${app.name}"-"${?MODULE_NAME}"-"${environment}
  
  executor {
    memory = "2g"
    cores = 2
    instances = 1
  }
  
  driver {
    memory = "1g"
    max-result-size = "1g"
  }
  
  dynamic-allocation {
    enabled = false
    min-executors = 1
    max-executors = 4
    initial-executors = 2
  }
  
  sql {
    shuffle-partitions = 8
    adaptive {
      enabled = true
      coalesce-partitions = true
      skew-join = true
    }
  }
}
```

### Database Configuration
```hocon
database {
  host = "localhost"
  port = 5432
  name = "smartstar_dev"
  username = "dev_user"
  password = "dev_password"
  driver = "org.postgresql.Driver"
  ssl = false
  connection-pool-size = 10
  connection-timeout = "30s"
}
```

### Storage Configuration
```hocon
storage {
  base-path = "/tmp/smartstar/dev"
  
  formats {
    input = "parquet"
    output = "delta"
    intermediate = "parquet"
  }
  
  compression = "snappy"
  
  paths {
    raw = ${storage.base-path}"/raw"
    processed = ${storage.base-path}"/processed"
    curated = ${storage.base-path}"/curated"
    temp = ${storage.base-path}"/temp"
    checkpoints = ${storage.base-path}"/checkpoints"
    failed = ${storage.base-path}"/failed"
  }
}
```

### Kafka Configuration
```hocon
kafka {
  bootstrap-servers = "localhost:9092"
  group-id = "smartstar-dev"
  auto-offset-reset = "earliest"
  session-timeout = "30s"
  heartbeat-interval = "3s"
  
  consumer {
    max-poll-records = 500
    fetch-min-bytes = 1024
    max-partition-fetch-bytes = 1048576
  }
  
  producer {
    batch-size = 16384
    linger-ms = 1
    compression-type = "snappy"
    max-request-size = 2097152
  }
}
```

### Monitoring Configuration
```hocon
monitoring {
  metrics {
    enabled = true
    namespace = "smartstar"
    reporting-interval = "30s"
  }
  
  health-check {
    enabled = true
    interval = "60s"
    timeout = "10s"
  }
  
  logging {
    level = "INFO"
    loggers {
      "com.smartstar" = "DEBUG"
      "org.apache.spark" = "WARN"
    }
  }
}
```

### Data Quality Configuration
```hocon
data-quality {
  enabled = true
  fail-on-error = false
  
  rules {
    null-check = true
    format-validation = true
    range-validation = true
    custom-validation = true
    schema-validation = false
    duplicate-detection = false
    data-profiling = false
  }
  
  thresholds {
    error-rate = 0.05      # 5% error rate threshold
    completeness = 0.95    # 95% completeness threshold
    uniqueness = 0.98      # 98% uniqueness threshold
    schema-compliance = 0.95
  }
}
```

## Environment-Specific Configurations

### Development Environment
- Uses `local[*]` Spark master
- Minimal resources (2g executor memory, 2 cores)
- Debug logging enabled
- Local file system storage
- UI enabled for debugging

### Staging Environment
- Uses cluster manager (YARN/Kubernetes)
- Moderate resources
- Mirrors production setup with reduced scale
- Enhanced monitoring

### Production Environment
- Uses cluster manager with auto-scaling
- Maximum resources and performance optimizations
- Strict security settings (SSL enabled, UI disabled)
- Advanced monitoring and alerting
- Distributed storage (S3/HDFS)

### Test Environment
- Minimal resources for fast execution
- UI disabled
- In-memory storage where possible
- Simplified configuration

## Configuration Validation

The system provides comprehensive configuration validation:

### Automatic Validation
- Required paths validation
- Type checking
- Environment-specific rules (e.g., production shouldn't use localhost)
- Module-specific validation

### Custom Validation
```scala
class MyJob extends SparkJob with ConfigurableJob {
  override def validateConfig(): Unit = {
    super.validateConfig() // Run standard validation
    
    // Add custom validation
    require(config.storageConfig.basePath.startsWith("s3://"), 
      "Production jobs must use S3 storage")
  }
}
```

## Configuration Override Patterns

### Environment Variables
```bash
export ENVIRONMENT=production
export MODULE_NAME=ingestion
export SMARTSTAR_DB_PASSWORD=secret123
```

### System Properties
```bash
java -Denvironment=production -DMODULE_NAME=ingestion -jar myapp.jar
```

### Programmatic Override
```scala
val config = ConfigurationFactory.forEnvironment(Environment.Production)
val customConfig = config.copy(
  sparkConfig = config.sparkConfig.copy(master = "yarn-cluster")
)
```

## Best Practices

1. **Use ConfigurationFactory**: Always use `ConfigurationFactory` for consistent configuration loading
2. **Validate Early**: Call `validateConfig()` at the start of job execution
3. **Environment Detection**: Let the system auto-detect environments rather than hardcoding
4. **Module Specification**: Explicitly specify modules using `MODULE_NAME` environment variable
5. **Sensitive Data**: Use environment variables for passwords and secrets
6. **Testing**: Use `ConfigurationFactory.forTesting()` for unit tests
7. **Documentation**: Document any custom configuration added to modules

## Troubleshooting

### Common Issues

1. **Configuration Not Found**
   - Check file paths and includes in `application.conf`
   - Verify environment variable names
   - Check classpath includes config directory

2. **Environment Not Detected**
   - Set `ENVIRONMENT` or `environment` system property explicitly
   - Check environment variable spelling and case

3. **Module Configuration Missing**
   - Set `MODULE_NAME` environment variable
   - Verify module config file exists in `config/modules/`

4. **Validation Failures**
   - Check required configuration paths are present
   - Verify environment-specific requirements (e.g., production settings)

### Debug Configuration
```scala
// Print all configuration for debugging
ConfigurationFactory.printAllConfigSummaries()

// Validate consistency across environments
val isValid = ConfigurationFactory.validateConsistency()

// Get specific environment summary
val summary = ConfigurationFactory.getConfigSummary(Environment.Production)
```

## Migration Guide

### From Old Configuration System

1. Replace `AppConfig.load()` with `ConfigurationFactory.forModule("module-name")`
2. Update job classes to extend `ConfigurableJob`
3. Add environment detection to deployment scripts
4. Move hardcoded configuration to appropriate config files
5. Add validation calls in job classes

### Example Migration
```scala
// Before
class MyJob extends SparkJob {
  val config = AppConfig.load()
  // ...
}

// After
class MyJob extends SparkJob with ConfigurableJob {
  override def config: AppConfig = ConfigurationFactory.forModule("ingestion")
  
  override def run(args: Array[String]): Unit = {
    validateConfig()
    // ...
  }
}
```