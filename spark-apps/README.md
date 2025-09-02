# "smartstar-spark-apps"

Multi-application Spark project for data processing pipeline.

## Structure

- **common**: Shared utilities and configurations
- **ingestion-app**: Data ingestion from various sources
- **normalization-app**: Data cleaning and normalization
- **analytics-app**: Data analysis and aggregations

## Usage

```bash
# Build all applications
sbt clean assembly

sbt "normalization-app/assembly"

# Run individual applications
sbt "ingestionApp/run"
sbt "normalizationApp/run" 
sbt "analyticsApp/run"
```

# Run
```bash
export ENV = "dev"
export MODULE_NAME = "development"