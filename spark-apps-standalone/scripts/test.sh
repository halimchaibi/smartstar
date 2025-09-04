#!/bin/bash

echo "🧪 Running SmartStar Spark Application Tests..."

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

# Run all tests
echo "Running all tests..."
$SBT_CMD test

# Generate test coverage report (if scoverage plugin is added)
echo "Generating test coverage report..."
$SBT_CMD coverage test coverageReport

echo "✅ All tests completed!"
