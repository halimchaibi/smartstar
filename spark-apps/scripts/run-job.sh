#!/bin/bash

if [ $# -lt 2 ]; then
    echo "❌ Usage: $0 <module> <job-class> [spark-args...]"
    echo ""
    echo "📋 Available modules:"
    echo "  - ingestion"
    echo "  - normalization" 
    echo "  - analytics"
    echo ""
    echo "📋 Example jobs:"
    echo "  ./run-job.sh ingestion com.smartstar.ingestion.batch.FileIngestionJob input/ output/"
    echo "  ./run-job.sh normalization com.smartstar.normalization.cleaning.DataCleansingJob"
    echo "  ./run-job.sh analytics com.smartstar.analytics.batch.AggregationJob"
    exit 1
fi

MODULE=$1
JOB_CLASS=$2
shift 2

JAR_FILE="target/scala-2.13/smartstar-${MODULE}-assembly-1.0.0.jar"

if [ ! -f "$JAR_FILE" ]; then
    echo "❌ JAR file not found: $JAR_FILE"
    echo "Please run './scripts/build.sh' first"
    exit 1
fi

echo "🚀 Running Spark job: $JOB_CLASS"
echo "📦 Using JAR: $JAR_FILE"
echo "📊 Module: $MODULE"
echo ""

spark-submit \
  --class "$JOB_CLASS" \
  --master local[*] \
  --deploy-mode client \
  --driver-memory 2g \
  --executor-memory 2g \
  --conf spark.sql.adaptive.enabled=true \
  --conf spark.sql.adaptive.coalescePartitions.enabled=true \
  "$JAR_FILE" \
  "$@"

echo ""
echo "✅ Job execution completed!"


#

set -e

# Parse arguments
MODULE="$1"
JOB_CLASS="$2"
shift 2
JOB_ARGS=("$@")

# Set environment variables
export SPARK_ENV="${SPARK_ENV:-development}"
export MODULE_NAME="$MODULE"

# Determine JAR file
JAR_FILE="target/scala-2.13/smartstar-${MODULE}-assembly-1.0.0.jar"

if [[ ! -f "$JAR_FILE" ]]; then
    echo "❌ JAR file not found: $JAR_FILE"
    echo "Please run 'sbt assembly' first"
    exit 1
fi

echo "🚀 Running Spark job:"
echo "  Environment: $SPARK_ENV"
echo "  Module: $MODULE_NAME"
echo "  Job Class: $JOB_CLASS"
echo "  JAR: $JAR_FILE"

# Submit job with environment variables
spark-submit \
  --class "$JOB_CLASS" \
  --master local[*] \
  --conf "spark.executorEnv.SPARK_ENV=$SPARK_ENV" \
  --conf "spark.executorEnv.MODULE_NAME=$MODULE_NAME" \
  "$JAR_FILE" \
  "${JOB_ARGS[@]}"

# ===== SUMMARY OF BENEFITS =====

# 1. CENTRALIZED CONFIGURATION
All Spark modules share the same config structure in spark-apps/config/

# 2. MODULE-SPECIFIC OVERRIDES
Each module can have specific settings in config/modules/*.conf

# 3. ENVIRONMENT MANAGEMENT
Single place to manage dev/staging/production across all modules

# 4. BUILD INTEGRATION
SBT automatically includes config/ in classpath for all modules

# 5. EASY ACCESS
All modules can access config via: AppConfig.load()

# 6. FLEXIBLE DEPLOYMENT
Can override configs via environment variables or external files