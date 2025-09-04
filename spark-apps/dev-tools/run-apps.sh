#!/bin/bash

# Improved Spark Job Runner Script
set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
WITH_DATA_PROVIDER=false
for arg in "$@"; do
    case $arg in
        --with-data-provider)
            WITH_DATA_PROVIDER=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--with-data-provider]"
            echo "  --with-data-provider  Start the data generator in background before running Spark job"
            exit 0
            ;;
        *)
            log_error "Unknown argument: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Configuration
PROJECT_NAME="ingestion"
MAIN_CLASS="com.smartstar.ingestion.streaming.KafkaStreamingJob"

# Navigate from dev-tools to spark-apps
cd "$(dirname "$0")/.." || {
    log_error "Cannot find spark-apps directory"
    exit 1
}

log_info "Working directory: $(pwd)"

# Verify we're in the right place
if [ ! -f "build.sbt" ]; then
    log_error "build.sbt not found. Are we in the correct directory?"
    exit 1
fi

# Start data provider if requested
if [ "$WITH_DATA_PROVIDER" = true ]; then
    log_info "Starting data generator in background..."
    
    if [ -f "launch-data-generator.sh" ]; then
        nohup ./launch-data-generator.sh > data-generator.log 2>&1 &
        DATA_GENERATOR_PID=$!
        log_success "Data generator started with PID: $DATA_GENERATOR_PID"
        log_info "Data generator logs: tail -f data-generator.log"
        
        # Wait a moment for the data generator to initialize
        sleep 5
    else
        log_warning "launch-data-generator.sh not found. Skipping data generator."
    fi
fi

# SBT JVM settings
export SBT_OPTS="-Xmx4G -Xms2G -XX:+UseG1GC"

# S3/MinIO credentials for local development
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
export AWS_ENDPOINT_URL=http://localhost:9000

log_info "Starting Spark job build and execution..."

# Create required directories
log_info "Creating required directories..."
mkdir -p /tmp/spark-events-dev
mkdir -p /tmp/spark-warehouse

# Clean up any existing bg-jobs that might cause issues
log_info "Cleaning up temporary directories..."
find target -name "bg-jobs" -type d -exec rm -rf {} + 2>/dev/null || true

# Build the project
log_info "Building project..."
if sbt clean compile; then
    log_success "Project compiled successfully"
else
    log_error "Compilation failed"
    exit 1
fi

# Check if MinIO is running (optional dependency check)
if curl -f -s http://localhost:9000/minio/health/live > /dev/null 2>&1; then
    log_success "MinIO is running and accessible"
else
    log_warning "MinIO is not accessible at http://localhost:9000"
    log_info "Make sure your Docker services are running: docker-compose up -d"
fi

# Run the Spark job
log_info "Starting Spark streaming job: $MAIN_CLASS"
log_info "Using S3 endpoint: $AWS_ENDPOINT_URL"

# Function to cleanup on exit
cleanup() {
    if [ "$WITH_DATA_PROVIDER" = true ] && [ -n "${DATA_GENERATOR_PID:-}" ]; then
        log_info "Cleaning up data generator (PID: $DATA_GENERATOR_PID)..."
        kill $DATA_GENERATOR_PID 2>/dev/null || true
        # Also stop the Docker container if it exists
        docker stop data-generator 2>/dev/null || true
    fi
}

# Set trap to cleanup on script exit
trap cleanup EXIT

if sbt 'set fork := false' "$PROJECT_NAME/runMain $MAIN_CLASS"; then
    log_success "Spark job completed successfully"
else
    log_error "Spark job failed"
    exit 1
fi

log_success "Script completed"