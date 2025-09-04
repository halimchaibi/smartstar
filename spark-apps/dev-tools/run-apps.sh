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

# Configuration
PROJECT_NAME="ingestion"
MAIN_CLASS="com.smartstar.ingestion.streaming.KafkaStreamingJob"

#!/bin/bash

# Navigate from dev-tools to spark-apps
cd "$(dirname "$0")/.." || {
    echo "Error: Cannot find spark-apps directory"
    exit 1
}

echo "Working directory: $(pwd)"

# Verify we're in the right place
if [ ! -f "build.sbt" ]; then
    echo "Error: build.sbt not found. Are we in the correct directory?"
    exit 1
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

# Optional: Build assembly JAR (uncomment if needed)
# log_info "Building assembly JAR..."
# if sbt assembly; then
#     log_success "Assembly JAR built successfully"
# else
#     log_error "Assembly build failed"
#     exit 1
# fi

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

if sbt 'set fork := false' "$PROJECT_NAME/runMain $MAIN_CLASS"; then
    log_success "Spark job completed successfully"
else
    log_error "Spark job failed"
    exit 1
fi

log_success "Script completed"