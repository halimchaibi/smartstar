#!/bin/bash

echo "🔨 Building SmartStar Spark Applications..."

# Find SBT (local or system)
SBT_CMD=""
if command -v sbt &> /dev/null; then
    SBT_CMD="sbt"
elif [ -x "../../sbt/bin/sbt" ]; then
    SBT_CMD="../../sbt/bin/sbt"
elif [ -x "../sbt/bin/sbt" ]; then
    SBT_CMD="../sbt/bin/sbt"
else
    echo "❌ SBT is not installed and not found locally. Please install SBT first."
    exit 1
fi

echo "Using SBT: $SBT_CMD"

# Clean and compile
echo "🧹 Cleaning previous builds..."
$SBT_CMD clean

echo "⚙️  Compiling source code..."
$SBT_CMD compile

# Run tests
echo "🧪 Running tests..."
$SBT_CMD test

# Create assembly JARs
echo "📦 Creating assembly JARs..."
$SBT_CMD assembly

echo "✅ Build completed successfully!"
echo ""
echo "📋 Build Summary:"
echo "- Compiled all modules: common, ingestion, normalization, analytics"
echo "- Ran unit tests"
echo "- Created fat JARs for deployment"
echo ""
echo "🚀 Ready to run Spark jobs!"
