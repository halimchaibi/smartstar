#!/bin/bash

echo "🔨 Building SmartStar Spark Applications..."

# Check if SBT is installed
if ! command -v sbt &> /dev/null; then
    echo "❌ SBT is not installed. Please install SBT first."
    exit 1
fi

# Clean and compile
echo "🧹 Cleaning previous builds..."
sbt clean

echo "⚙️  Compiling source code..."
sbt compile

# Run tests
echo "🧪 Running tests..."
sbt test

# Create assembly JARs
echo "📦 Creating assembly JARs..."
sbt assembly

echo "✅ Build completed successfully!"
echo ""
echo "📋 Build Summary:"
echo "- Compiled all modules: common, ingestion, normalization, analytics"
echo "- Ran unit tests"
echo "- Created fat JARs for deployment"
echo ""
echo "🚀 Ready to run Spark jobs!"
