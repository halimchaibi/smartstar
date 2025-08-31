#!/bin/bash

echo "🧪 Running SmartStar Spark Application Tests..."

# Run all tests
echo "Running all tests..."
sbt test

# Generate test coverage report (if scoverage plugin is added)
echo "Generating test coverage report..."
sbt coverage test coverageReport

echo "✅ All tests completed!"
