#!/bin/bash

# Quickstart Script for Spark Apps
# This script builds the entire project using sbt assembly

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

echo "🚀 Spark Apps - Quickstart Build Script"
echo "======================================"

# Check if we're in the right directory
if [ ! -f "build.sbt" ]; then
    log_error "build.sbt not found. Please run this script from the project root directory."
    exit 1
fi

# Check if SBT is available
if ! command -v sbt &> /dev/null; then
    log_warning "SBT not found in PATH. Checking if local sbt is available..."
    
    # Check for local sbt in parent directory (common in some setups)
    if [ -f "../sbt/bin/sbt" ]; then
        log_info "Using local SBT installation..."
        SBT_CMD="../sbt/bin/sbt"
    else
        log_error "SBT is not installed or not found in PATH."
        log_error "Please install SBT first: https://www.scala-sbt.org/download.html"
        exit 1
    fi
else
    SBT_CMD="sbt"
fi

log_info "Using SBT command: $SBT_CMD"

# Clean previous builds
log_info "🧹 Cleaning previous builds..."
$SBT_CMD clean

# Compile all modules
log_info "⚙️  Compiling all modules..."
$SBT_CMD compile

# Run tests
log_info "🧪 Running tests..."
$SBT_CMD test

# Create assembly JARs
log_info "📦 Creating assembly JARs..."
export SBT_OPTS="-Xmx2g -XX:+UseG1GC"
$SBT_CMD assembly

# Verify that assembly JARs were created
log_info "🔍 Verifying assembly JARs..."

ASSEMBLY_DIR="target/scala-2.13"
if [ -d "modules" ]; then
    # Check each module
    for module in common ingestion normalization analytics; do
        JAR_PATH="modules/$module/target/scala-2.13/smartstar-$module-assembly-1.0.0.jar"
        if [ -f "$JAR_PATH" ]; then
            log_success "Created: $JAR_PATH"
        else
            log_warning "Assembly JAR not found: $JAR_PATH"
        fi
    done
else
    log_warning "modules/ directory not found. Checking for JARs in target/..."
    find target -name "*assembly*.jar" -type f | while read jar; do
        log_success "Created: $jar"
    done
fi

echo ""
log_success "🎉 Build completed successfully!"
echo ""
echo "📋 Build Summary:"
echo "- ✅ Cleaned previous builds"
echo "- ✅ Compiled all modules (common, ingestion, normalization, analytics)"
echo "- ✅ Ran unit tests"
echo "- ✅ Created fat JARs for deployment"
echo ""
echo "🚀 Ready to run Spark jobs!"
echo ""
echo "Next steps:"
echo "1. Set up development environment: ./dev-tools/setup-dev-env.sh"
echo "2. Generate test data: ./dev-tools/launch-data-generator.sh"
echo "3. Run applications: ./dev-tools/run-apps.sh"
echo ""
echo "For manual execution, use:"
echo "  spark-submit --class <MainClass> --master local[*] modules/<module>/target/scala-2.13/smartstar-<module>-assembly-1.0.0.jar"