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