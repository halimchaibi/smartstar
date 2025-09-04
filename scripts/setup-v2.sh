#!/bin/bash
# ===== Environment Setup Script (scripts/setup-environment.sh) =====

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🌍 SmartStar Environment Setup"
echo "==============================="

# Function to prompt for environment
select_environment() {
    echo "Select target environment:"
    echo "1) Development (local)"
    echo "2) Staging"  
    echo "3) Production"
    echo "4) Test"
    
    read -p "Enter choice (1-4): " env_choice
    
    case $env_choice in
        1) export SPARK_ENV="development";;
        2) export SPARK_ENV="staging";;
        3) export SPARK_ENV="production";;
        4) export SPARK_ENV="test";;
        *) echo "Invalid choice. Defaulting to development."; export SPARK_ENV="development";;
    esac
    
    echo "✅ Environment set to: $SPARK_ENV"
}

# Function to validate environment requirements
validate_environment() {
    echo "🔍 Validating environment requirements..."
    
    case $SPARK_ENV in
        "production")
            echo "🔐 Production environment detected"
            
            if [[ -z "$SMARTSTAR_DB_USER" ]]; then
                read -p "Enter database username: " SMARTSTAR_DB_USER
                export SMARTSTAR_DB_USER
            fi
            
            if [[ -z "$SMARTSTAR_DB_PASSWORD" ]]; then
                read -s -p "Enter database password: " SMARTSTAR_DB_PASSWORD
                export SMARTSTAR_DB_PASSWORD
                echo
            fi
            
            echo "✅ Production credentials configured"
            ;;
            
        "staging")
            echo "🧪 Staging environment detected"
            
            if [[ -z "$SMARTSTAR_DB_USER" ]]; then
                read -p "Enter staging database username: " SMARTSTAR_DB_USER  
                export SMARTSTAR_DB_USER
            fi
            
            if [[ -z "$SMARTSTAR_DB_PASSWORD" ]]; then
                read -s -p "Enter staging database password: " SMARTSTAR_DB_PASSWORD
                export SMARTSTAR_DB_PASSWORD
                echo
            fi
            
            echo "✅ Staging credentials configured"
            ;;
            
        "development")
            echo "💻 Development environment - using defaults"
            ;;
            
        "test")
            echo "🧪 Test environment - using in-memory database"
            ;;
    esac
}

# Function to create environment-specific configuration
create_environment_config() {
    echo "📝 Creating environment-specific configuration..."
    
    CONFIG_DIR="$PROJECT_DIR/config/environments/$SPARK_ENV"
    mkdir -p "$CONFIG_DIR"
    
    # Create environment-specific application.conf if it doesn't exist
    if [[ ! -f "$CONFIG_DIR/application.conf" ]]; then
        echo "Creating $CONFIG_DIR/application.conf..."
        
        case $SPARK_ENV in
            "development")
                cat > "$CONFIG_DIR/application.conf" << 'EOF'
include "../../common.conf"

environment = "development"

# Override any development-specific settings here
spark {
  ui {
    port = 4040
  }
}

database {
  url = "jdbc:postgresql://localhost:5432/smartstar_dev"
  username = "dev_user"
  password = "dev_password"
}
EOF
                ;;
                
            "staging")
                cat > "$CONFIG_DIR/application.conf" << 'EOF'
include "../../common.conf"

environment = "staging"

database {
  url = "jdbc:postgresql://staging-postgres:5432/smartstar_staging"
  username = ${SMARTSTAR_DB_USER}
  password = ${SMARTSTAR_DB_PASSWORD}
}
EOF
                ;;
                
            "production")
                cat > "$CONFIG_DIR/application.conf" << 'EOF'
include "../../common.conf"

environment = "production"

database {
  url = "jdbc:postgresql://prod-postgres-cluster:5432/smartstar_prod"
  username = ${SMARTSTAR_DB_USER}
  password = ${SMARTSTAR_DB_PASSWORD}
}
EOF
                ;;
        esac
        
        echo "✅ Configuration created: $CONFIG_DIR/application.conf"
    else
        echo "ℹ️  Configuration already exists: $CONFIG_DIR/application.conf"
    fi
}

# Function to set up environment variables
setup_environment_variables() {
    echo "🔧 Setting up environment variables..."
    
    # Create .env file for the environment
    ENV_FILE="$PROJECT_DIR/.env.$SPARK_ENV"
    
    cat > "$ENV_FILE" << EOF
# SmartStar Environment Configuration for $SPARK_ENV
SPARK_ENV=$SPARK_ENV
ENVIRONMENT=$SPARK_ENV

# Spark Configuration
SPARK_HOME=${SPARK_HOME:-/opt/spark}
HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-/etc/hadoop/conf}

# Application Configuration
SMARTSTAR_CONFIG_PATH=config/environments/$SPARK_ENV
SMARTSTAR_LOG_LEVEL=${SMARTSTAR_LOG_LEVEL:-INFO}

EOF

    # Add environment-specific variables
    case $SPARK_ENV in
        "production"|"staging")
            cat >> "$ENV_FILE" << EOF
# Database Configuration
SMARTSTAR_DB_USER=$SMARTSTAR_DB_USER
SMARTSTAR_DB_PASSWORD=$SMARTSTAR_DB_PASSWORD

# Cloud Configuration  
AWS_REGION=${AWS_REGION:-us-east-1}
EOF
            ;;
    esac
    
    echo "✅ Environment file created: $ENV_FILE"
    echo "💡 To activate: source $ENV_FILE"
}

# Function to validate Spark installation
validate_spark() {
    echo "⚡ Validating Spark installation..."
    
    if command -v spark-submit &> /dev/null; then
        SPARK_VERSION=$(spark-submit --version 2>&1 | grep "version" | head -1 | awk '{print $5}')
        echo "✅ Spark found: $SPARK_VERSION"
    else
        echo "⚠️  Spark not found in PATH"
        echo "   Please install Spark or set SPARK_HOME"
    fi
    
    if command -v sbt &> /dev/null; then
        SBT_VERSION=$(sbt sbtVersion 2>/dev/null | grep "sbt version" | awk '{print $4}' || echo "unknown")
        echo "✅ SBT found: $SBT_VERSION"
    else
        echo "❌ SBT not found - required for building"
        echo "   Install from: https://www.scala-sbt.org/"
    fi
}

# Function to display environment summary
show_environment_summary() {
    echo ""
    echo "🎯 Environment Setup Complete!"
    echo "================================"
    echo "Environment: $SPARK_ENV"
    echo "Config Path: config/environments/$SPARK_ENV"
    echo "Env File: .env.$SPARK_ENV"
    echo ""
    echo "🚀 Next Steps:"
    echo "1. Activate environment: source .env.$SPARK_ENV"
    echo "2. Build project: cd spark-apps && ./scripts/build.sh"
    echo "3. Run job: ./scripts/run-job.sh ingestion com.smartstar.ingestion.SmartStarFileIngestionJob"
    echo ""
}

# Main execution
main() {
    select_environment
    validate_environment
    create_environment_config
    setup_environment_variables
    validate_spark
    show_environment_summary
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# ===== Enhanced Run Job Script (spark-apps/scripts/run-job-env.sh) =====
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
DEFAULT_ENV="development"
DEFAULT_MASTER="local[*]"
DEFAULT_DRIVER_MEMORY="2g"
DEFAULT_EXECUTOR_MEMORY="2g"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] <module> <job-class> [job-args...]"
    echo ""
    echo "Options:"
    echo "  -e, --env <environment>     Environment (development|staging|production|test)"
    echo "  -m, --master <master>       Spark master URL"
    echo "  -c, --conf <key=value>      Additional Spark configuration"
    echo "  --driver-memory <memory>    Driver memory (default: $DEFAULT_DRIVER_MEMORY)"
    echo "  --executor-memory <memory>  Executor memory (default: $DEFAULT_EXECUTOR_MEMORY)"
    echo "  --dry-run                   Show command without executing"
    echo "  -h, --help                  Show this help"
    echo ""
    echo "Modules: ingestion, normalization, analytics"
    echo ""
    echo "Examples:"
    echo "  $0 -e production ingestion com.smartstar.ingestion.SmartStarFileIngestionJob s3://input/ s3://output/"
    echo "  $0 -e staging --driver-memory 4g analytics com.smartstar.analytics.batch.AggregationJob"
    echo "  $0 --dry-run ingestion com.smartstar.ingestion.SmartStarFileIngestionJob"
    echo ""
}

# Parse command line arguments
parse_args() {
    ENVIRONMENT="$DEFAULT_ENV"
    MASTER=""
    DRIVER_MEMORY="$DEFAULT_DRIVER_MEMORY"
    EXECUTOR_MEMORY="$DEFAULT_EXECUTOR_MEMORY"
    ADDITIONAL_CONF=()
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--master)
                MASTER="$2"
                shift 2
                ;;
            -c|--conf)
                ADDITIONAL_CONF+=("--conf" "$2")
                shift 2
                ;;
            --driver-memory)
                DRIVER_MEMORY="$2"
                shift 2
                ;;
            --executor-memory)
                EXECUTOR_MEMORY="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Remaining arguments
    MODULE="$1"
    JOB_CLASS="$2"
    shift 2 2>/dev/null || true
    JOB_ARGS=("$@")
}

# Function to validate arguments
validate_args() {
    if [[ -z "$MODULE" ]]; then
        echo "❌ Module is required"
        show_usage
        exit 1
    fi
    
    if [[ -z "$JOB_CLASS" ]]; then
        echo "❌ Job class is required"
        show_usage
        exit 1
    fi
    
    # Validate module
    case "$MODULE" in
        ingestion|normalization|analytics) ;;
        *)
            echo "❌ Invalid module: $MODULE"
            echo "Valid modules: ingestion, normalization, analytics"
            exit 1
            ;;
    esac
    
    # Validate environment
    case "$ENVIRONMENT" in
        development|staging|production|test) ;;
        *)
            echo "❌ Invalid environment: $ENVIRONMENT"
            echo "Valid environments: development, staging, production, test"
            exit 1
            ;;
    esac
}

# Function to determine master based on environment
determine_master() {
    if [[ -n "$MASTER" ]]; then
        return # Use provided master
    fi
    
    case "$ENVIRONMENT" in
        development|test)
            MASTER="local[*]"
            ;;
        staging|production)
            MASTER="yarn"
            ;;
    esac
}

# Function to get environment-specific configurations
get_environment_configs() {
    ENV_CONFIGS=()
    
    case "$ENVIRONMENT" in
        development)
            ENV_CONFIGS+=(
                "--conf" "spark.ui.enabled=true"
                "--conf" "spark.ui.port=4040"
                "--conf" "spark.sql.shuffle.partitions=8"
            )
            ;;
        staging)
            ENV_CONFIGS+=(
                "--conf" "spark.sql.shuffle.partitions=200"
                "--conf" "spark.sql.adaptive.advisoryPartitionSizeInBytes=256MB"
                "--conf" "spark.dynamicAllocation.enabled=true"
                "--conf" "spark.dynamicAllocation.minExecutors=2"
                "--conf" "spark.dynamicAllocation.maxExecutors=20"
            )
            ;;
        production)
            ENV_CONFIGS+=(
                "--conf" "spark.sql.shuffle.partitions=400"
                "--conf" "spark.sql.adaptive.advisoryPartitionSizeInBytes=512MB"
                "--conf" "spark.dynamicAllocation.enabled=true"
                "--conf" "spark.dynamicAllocation.minExecutors=5"
                "--conf" "spark.dynamicAllocation.maxExecutors=100"
                "--conf" "spark.sql.streaming.stopGracefullyOnShutdown=true"
            )
            ;;
        test)
            ENV_CONFIGS+=(
                "--conf" "spark.ui.enabled=false"
                "--conf" "spark.sql.shuffle.partitions=2"
                "--conf" "spark.default.parallelism=2"
            )
            ;;
    esac
}

# Function to build spark-submit command
build_spark_command() {
    JAR_FILE="target/scala-2.13/smartstar-${MODULE}-assembly-1.0.0.jar"
    
    if [[ ! -f "$JAR_FILE" ]]; then
        echo "❌ JAR file not found: $JAR_FILE"
        echo "Please run './scripts/build.sh' first"
        exit 1
    fi
    
    # Build the command
    SPARK_CMD=(
        "spark-submit"
        "--class" "$JOB_CLASS"
        "--master" "$MASTER"
        "--deploy-mode" "client"
        "--driver-memory" "$DRIVER_MEMORY"
        "--executor-memory" "$EXECUTOR_MEMORY"
    )
    
    # Add environment configs
    get_environment_configs
    SPARK_CMD+=("${ENV_CONFIGS[@]}")
    
    # Add additional configurations
    SPARK_CMD+=("${ADDITIONAL_CONF[@]}")
    
    # Add environment variable
    SPARK_CMD+=(
        "--conf" "spark.executorEnv.SPARK_ENV=$ENVIRONMENT"
        "--conf" "spark.executorEnv.ENVIRONMENT=$ENVIRONMENT"
    )
    
    # Add JAR and job arguments
    SPARK_CMD+=("$JAR_FILE")
    SPARK_CMD+=("${JOB_ARGS[@]}")
}

# Function to display job info
show_job_info() {
    echo "🚀 SmartStar Job Execution"
    echo "=========================="
    echo "Environment: $ENVIRONMENT"
    echo "Module: $MODULE"
    echo "Job Class: $JOB_CLASS"
    echo "Master: $MASTER"
    echo "Driver Memory: $DRIVER_MEMORY"
    echo "Executor Memory: $EXECUTOR_MEMORY"
    echo "JAR: $JAR_FILE"
    
    if [[ ${#JOB_ARGS[@]} -gt 0 ]]; then
        echo "Arguments: ${JOB_ARGS[*]}"
    fi
    
    echo ""
}

# Function to execute the job
execute_job() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "🔍 Dry Run - Command that would be executed:"
        echo "${SPARK_CMD[*]}"
        return 0
    fi
    
    echo "▶️  Executing Spark job..."
    echo ""
    
    # Set environment variables
    export SPARK_ENV="$ENVIRONMENT"
    export ENVIRONMENT="$ENVIRONMENT"
    
    # Execute the command
    "${SPARK_CMD[@]}"
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo ""
        echo "✅ Job completed successfully!"
    else
        echo ""
        echo "❌ Job failed with exit code: $exit_code"
    fi
    
    return $exit_code
}

# Main execution
main() {
    parse_args "$@"
    validate_args
    determine_master
    build_spark_command
    show_job_info
    execute_job
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# ===== Environment Configuration Helper (scripts/config-helper.sh) =====
#!/bin/bash

set -e

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)"

# Function to show current configuration
show_config() {
    local environment=${1:-"development"}
    
    echo "🔧 SmartStar Configuration for: $environment"
    echo "============================================="
    
    local env_config="$CONFIG_DIR/environments/$environment/application.conf"
    
    if [[ -f "$env_config" ]]; then
        echo "📁 Config file: $env_config"
        echo ""
        echo "📋 Configuration preview:"
        head -20 "$env_config"
        echo "..."
    else
        echo "❌ Configuration not found: $env_config"
    fi
}

# Function to validate configuration
validate_config() {
    local environment=${1:-"development"}
    
    echo "🔍 Validating configuration for: $environment"
    
    local env_config="$CONFIG_DIR/environments/$environment/application.conf"
    local common_config="$CONFIG_DIR/common.conf"
    
    # Check if files exist
    if [[ ! -f "$common_config" ]]; then
        echo "❌ Common configuration missing: $common_config"
        return 1
    fi
    
    if [[ ! -f "$env_config" ]]; then
        echo "❌ Environment configuration missing: $env_config"
        return 1
    fi
    
    echo "✅ Configuration files exist"
    
    # Validate environment-specific requirements
    case "$environment" in
        "production"|"staging")
            if ! grep -q "SMARTSTAR_DB_USER" "$env_config"; then
                echo "⚠️  Database credentials use environment variables"
                echo "   Make sure SMARTSTAR_DB_USER and SMARTSTAR_DB_PASSWORD are set"
            fi
            ;;
    esac
    
    echo "✅ Configuration validation completed"
}

# Function to create missing configuration
create_config() {
    local environment=${1:-"development"}
    
    echo "📝 Creating configuration for: $environment"
    
    local env_dir="$CONFIG_DIR/environments/$environment"
    local env_config="$env_dir/application.conf"
    
    mkdir -p "$env_dir"
    
    if [[ -f "$env_config" ]]; then
        echo "ℹ️  Configuration already exists: $env_config"
        return 0
    fi
    
    # Create environment-specific config
    case "$environment" in
        "development")
            cat > "$env_config" << 'EOF'
include "../../common.conf"

environment = "development"

# Development-specific overrides
spark {
  ui.enabled = true
  ui.port = 4040
}

database {
  url = "jdbc:postgresql://localhost:5432/smartstar_dev"
  username = "dev_user"
  password = "dev_password"
}

storage {
  base-path = "/tmp/smartstar/dev"
  checkpoint-location = "/tmp/spark-checkpoint-dev"
}
EOF
            ;;
        "test")
            cat > "$env_config" << 'EOF'
include "../../common.conf"

environment = "test"

# Test-specific overrides
spark {
  ui.enabled = false
  sql.shuffle.partitions = 2
}

database {
  url = "jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1"
  username = "sa"
  password = ""
  driver = "org.h2.Driver"
}

storage {
  base-path = "/tmp/smartstar/test"
  checkpoint-location = "/tmp/spark-checkpoint-test"
}
EOF
            ;;
        *)
            echo "❌ Unsupported environment for auto-creation: $environment"
            echo "Please create manually: $env_config"
            return 1
            ;;
    esac
    
    echo "✅ Created configuration: $env_config"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <command> [environment]"
    echo ""
    echo "Commands:"
    echo "  show <env>      Show configuration for environment"
    echo "  validate <env>  Validate configuration for environment"
    echo "  create <env>    Create missing configuration for environment"
    echo "  list           List available environments"
    echo ""
    echo "Environments: development, staging, production, test"
    echo ""
    echo "Examples:"
    echo "  $0 show development"
    echo "  $0 validate production"
    echo "  $0 create test"
    echo ""
}

# Function to list environments
list_environments() {
    echo "📂 Available environments:"
    echo "========================="
    
    for env_dir in "$CONFIG_DIR/environments"/*; do
        if [[ -d "$env_dir" ]]; then
            local env_name=$(basename "$env_dir")
            local config_file="$env_dir/application.conf"
            
            if [[ -f "$config_file" ]]; then
                echo "✅ $env_name (configured)"
            else
                echo "⚠️  $env_name (missing config)"
            fi
        fi
    done
}

# Main execution
main() {
    local command="${1:-help}"
    local environment="${2:-development}"
    
    case "$command" in
        "show")
            show_config "$environment"
            ;;
        "validate")
            validate_config "$environment"
            ;;
        "create")
            create_config "$environment"
            ;;
        "list")
            list_environments
            ;;
        "help"|*)
            show_usage
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# ===== Usage Examples and Documentation =====

# Create usage examples file
cat > usage-examples.md << 'EOF'
# SmartStar Environment-Based Spark Session Usage

## Quick Start

### 1. Set Up Environment
```bash
# Interactive setup
./scripts/setup-environment.sh

# Or set manually
export SPARK_ENV=development
export SMARTSTAR_DB_USER=myuser
export SMARTSTAR_DB_PASSWORD=mypass
```

### 2. Build Project
```bash
cd spark-apps
./scripts/build.sh
```

### 3. Run Jobs with Environment
```bash
# Development environment (default)
./scripts/run-job-env.sh ingestion com.smartstar.ingestion.SmartStarFileIngestionJob input/ output/

# Production environment
./scripts/run-job-env.sh -e production ingestion com.smartstar.ingestion.SmartStarFileIngestionJob s3://input/ s3://output/

# Custom configurations
./scripts/run-job-env.sh -e staging --driver-memory 4g -c spark.sql.shuffle.partitions=400 analytics com.smartstar.analytics.batch.AggregationJob
```

## Writing Environment-Aware Jobs

### Basic Job Pattern
```scala
class MyJob extends SmartStarBatchJob {
  override def appName: String = "My-Job"
  override def config: AppConfig = AppConfig.load()
  
  override def executeBatch(args: Array[String]): Unit = {
    // Job logic here - spark session automatically configured for environment
    val df = spark.read.parquet(args(0))
    
    // Environment-specific behavior
    whenProduction {
      df.cache() // Only cache in production
    }
    
    df.write.parquet(args(1))
  }
}
```

### Streaming Job Pattern
```scala
class MyStreamingJob extends SmartStarStreamingJob {
  override def appName: String = "My-Streaming-Job"
  override def config: AppConfig = AppConfig.load()
  override def checkpointLocation: String = s"${config.storageConfig.checkpointLocation}/my-job"
  
  override def runStreaming(args: Array[String]): StreamingQuery = {
    // Streaming logic here
    spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", config.kafkaConfig.bootstrapServers)
      .load()
      .writeStream
      .start()
  }
}
```

### Custom Environment Configurations
```scala
class CustomConfigJob extends EnvironmentAwareSparkJob {
  override def appName: String = "Custom-Config-Job"
  override def config: AppConfig = AppConfig.load()
  
  // Override environment detection
  override def environment: Environment = Environment.Test
  
  // Add custom Spark configurations
  override def additionalSparkConfigs: Map[String, String] = Map(
    "spark.sql.adaptive.enabled" -> "false",
    "spark.serializer" -> "org.apache.spark.serializer.JavaSerializer"
  )
  
  override def run(args: Array[String]): Unit = {
    // Job logic
  }
}
```

## Configuration Management

### Environment-Specific Settings

#### Development (local)
- Uses local Spark master
- Small memory settings
- UI enabled
- Detailed logging

#### Staging
- Uses YARN cluster
- Medium memory settings
- Event logging enabled
- Moderate parallelism

#### Production
- Uses YARN cluster
- Large memory settings
- UI disabled for security
- High parallelism
- Fault tolerance enabled

#### Test
- Minimal resources
- In-memory database
- UI disabled
- Fast execution

### Configuration Files Structure
```
config/
├── common.conf                    # Base configuration
├── environments/
│   ├── development/
│   │   └── application.conf       # Dev-specific overrides
│   ├── staging/
│   │   └── application.conf       # Staging-specific overrides
│   ├── production/
│   │   └── application.conf       # Production-specific overrides
│   └── test/
│       └── application.conf       # Test-specific overrides
```

## Deployment Patterns

### Local Development
```bash
export SPARK_ENV=development
./scripts/run-job-env.sh ingestion com.smartstar.ingestion.SmartStarFileIngestionJob
```

### Staging Deployment
```bash
export SPARK_ENV=staging
export SMARTSTAR_DB_USER=staging_user
export SMARTSTAR_DB_PASSWORD=staging_pass
./scripts/run-job-env.sh -e staging --executor-memory 4g ingestion com.smartstar.ingestion.SmartStarFileIngestionJob
```

### Production Deployment
```bash
# Via script with credentials from environment
export SPARK_ENV=production
export SMARTSTAR_DB_USER=prod_user
export SMARTSTAR_DB_PASSWORD=prod_pass

spark-submit \
  --class com.smartstar.ingestion.SmartStarFileIngestionJob \
  --master yarn \
  --deploy-mode cluster \
  --executor-memory 8g \
  --driver-memory 4g \
  --conf spark.executorEnv.SPARK_ENV=production \
  smartstar-ingestion-assembly-1.0.0.jar \
  s3://input-bucket/ s3://output-bucket/
```

### Kubernetes Deployment
```bash
spark-submit \
  --master k8s://https://kubernetes.default.svc:443 \
  --deploy-mode cluster \
  --conf spark.kubernetes.container.image=smartstar/spark:latest \
  --conf spark.executorEnv.SPARK_ENV=production \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=smartstar \
  local:///opt/spark/jars/smartstar-ingestion-assembly-1.0.0.jar
```

## Testing Different Environments

### Unit Tests with Test Environment
```scala
class JobTest extends AnyFunSuite {
  test("job should run in test environment") {
    // Test environment automatically uses in-memory database
    val job = new MyJob() {
      override def environment: Environment = Environment.Test
    }
    
    job.run(Array("test-input", "test-output"))
    // Assertions
  }
}
```

### Integration Tests
```bash
# Run with test environment
export SPARK_ENV=test
./scripts/run-job-env.sh -e test ingestion com.smartstar.ingestion.SmartStarFileIngestionJob
```

## Troubleshooting

### Common Issues

1. **Environment not detected**: Set SPARK_ENV environment variable
2. **Configuration not found**: Run `./scripts/config-helper.sh create <env>`
3. **Database connection fails**: Check credentials and network connectivity
4. **Spark UI not accessible**: Check firewall settings and UI port configuration

### Debug Commands
```bash
# Validate configuration
./scripts/config-helper.sh validate production

# Show current configuration
./scripts/config-helper.sh show development

# Dry run to see command
./scripts/run-job-env.sh --dry-run ingestion com.smartstar.ingestion.SmartStarFileIngestionJob
```

EOF

echo "📚 Created comprehensive environment-based Spark session management system!"
echo ""
echo "Key Features:"
echo "✅ Environment detection (development/staging/production/test)"
echo "✅ Automatic Spark session configuration per environment"
echo "✅ Trait-based job structure with environment awareness"
echo "✅ Configuration management with environment-specific overrides"
echo "✅ Setup and deployment scripts"
echo "✅ Comprehensive documentation and examples"
echo ""
echo "Usage:"
echo "1. Run setup: ./scripts/setup-environment.sh"
echo "2. Build project: cd spark-apps && ./scripts/build.sh"  
echo "3. Run job: ./scripts/run-job-env.sh -e production ingestion com.smartstar.ingestion.SmartStarFileIngestionJob"
e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -
