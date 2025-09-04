# Spark Apps - Data Processing Applications

A collection of Apache Spark applications for data analytics, ingestion, normalization, and transformation. This project provides a modular architecture for building and deploying Spark-based data processing workflows.

## 🚀 What is this project?

This repository contains Spark applications designed for:

- **Data Ingestion**: Batch and streaming data ingestion from multiple sources (Kafka, files, databases)
- **Data Normalization**: Automated data cleansing, validation, and transformation pipelines
- **Analytics**: Advanced analytics, aggregations, and machine learning workloads
- **Common Utilities**: Shared configurations, utilities, and reusable components

The applications are built with a modular architecture that promotes code reuse and maintainability across different data processing stages.

## 📁 Project Structure

```
spark-apps/
├── modules/
│   ├── common/                # Shared utilities and configurations
│   ├── ingestion/             # Data ingestion applications
│   ├── normalization/         # Data cleansing and transformation
│   └── analytics/             # Analytics and ML workloads
├── dev-tools/                 # Development environment setup scripts
│   ├── setup-dev-env.sh      # Environment setup script
│   ├── launch-data-generator.sh # Data generator for testing
│   └── run-apps.sh           # Application runner script
├── scripts/                   # Build and deployment scripts
│   └── quickstart.sh         # Quick build and setup script
├── config/                    # Environment-specific configurations
├── docker/                    # Docker configurations for local development
└── project/                   # SBT build configuration
```

## 🛠️ Development Setup

### Prerequisites

- **Java 11+** (OpenJDK or Oracle JDK)
- **Scala 2.13.16**
- **Apache Spark 4.0.0** (for local testing)
- **SBT** (Scala Build Tool)
- **Docker & Docker Compose** (for local data stack)

### Quick Start

1. **Set up the development environment**:
   ```bash
   ./dev-tools/setup-dev-env.sh
   ```

2. **Build all applications**:
   ```bash
   ./scripts/quickstart.sh
   ```

3. **Run the test data generator**:
   ```bash
   ./dev-tools/launch-data-generator.sh
   ```

4. **Execute Spark applications**:
   ```bash
   ./dev-tools/run-apps.sh
   ```

### Manual Development Setup

#### 1. Environment Setup

The `setup-dev-env.sh` script will:
- Install required dependencies (Java, Scala, SBT, Spark)
- Set up Docker containers for local data stack (Kafka, MinIO, etc.)
- Configure environment variables
- Create necessary directories and permissions

```bash
cd dev-tools
./setup-dev-env.sh
```

#### 2. Building Applications

Build individual modules:
```bash
# Build all modules
sbt clean compile

# Build specific module
sbt "project common" compile
sbt "project ingestion" compile
sbt "project normalization" compile
sbt "project analytics" compile
```

Create deployable JAR files:
```bash
# Build all assembly JARs
sbt assembly

# Build specific module assembly
sbt "project ingestion" assembly
```

#### 3. Running Tests

```bash
# Run all tests
sbt test

# Run tests for specific module
sbt "project common" test
sbt "project ingestion" test
```

#### 4. Code Quality

```bash
# Format code
sbt scalafmt

# Check code style
sbt scalastyle

# Fix common issues
sbt scalafix
```

### Local Development Environment

#### Starting the Data Stack

The development environment includes:
- **Apache Kafka**: Message streaming platform
- **MinIO**: S3-compatible object storage
- **PostgreSQL**: Relational database
- **Redis**: In-memory data store

```bash
# Start all services
./dev-tools/setup-dev-env.sh

# Generate test data
./dev-tools/launch-data-generator.sh

# Run applications
./dev-tools/run-apps.sh
```

#### Environment Variables

Key environment variables for development:

```bash
export ENV=development
export MODULE_NAME=development
export SPARK_HOME=/path/to/spark
export JAVA_HOME=/path/to/java
```

## 🏃‍♂️ Running Applications

### Using the Run Script

The `run-apps.sh` script provides an easy way to execute different Spark applications:

```bash
# Run ingestion job
./dev-tools/run-apps.sh ingestion

# Run normalization job
./dev-tools/run-apps.sh normalization

# Run analytics job
./dev-tools/run-apps.sh analytics
```

### Manual Execution

You can also run applications manually using `spark-submit`:

```bash
spark-submit \
  --class com.smartstar.ingestion.batch.FileIngestionJob \
  --master local[*] \
  --driver-memory 2g \
  --executor-memory 2g \
  modules/ingestion/target/scala-2.13/smartstar-ingestion-assembly-1.0.0.jar \
  input/ output/
```

## 📊 Application Modules

### Common Module

Shared utilities and configurations used across all applications:
- Spark session management
- Configuration loading
- Logging utilities
- Exception handling
- Data quality validation

### Ingestion Module

Data ingestion from various sources:
- **Batch Ingestion**: File-based data loading (CSV, JSON, Parquet)
- **Streaming Ingestion**: Real-time data from Kafka streams
- **Database Ingestion**: Extract data from relational databases
- **API Ingestion**: REST API data collection

### Normalization Module

Data cleaning and transformation:
- **Data Validation**: Schema validation and data quality checks
- **Data Cleansing**: Remove duplicates, handle missing values
- **Data Transformation**: Format standardization and type conversion
- **Data Enrichment**: Add derived fields and business logic

### Analytics Module

Advanced analytics and aggregations:
- **Batch Analytics**: Historical data analysis and reporting
- **Real-time Analytics**: Streaming analytics with window functions
- **Machine Learning**: Feature engineering and model training
- **Data Aggregations**: Summary statistics and KPI calculations

## 🧪 Testing

### Unit Tests

Each module includes comprehensive unit tests:

```bash
# Run all tests
sbt test

# Run module-specific tests
sbt "project ingestion" test
```

### Integration Tests

Test end-to-end workflows:

```bash
# Start test environment
./dev-tools/setup-dev-env.sh

# Run integration tests
sbt "testOnly *IntegrationTest"
```

## 📦 Deployment

### Building for Production

```bash
# Build production JARs
export ENV=production
sbt clean assembly
```

### Deployment Options

1. **Spark Cluster**: Deploy to existing Spark cluster
2. **Kubernetes**: Use Spark on Kubernetes operator
3. **Cloud Platforms**: AWS EMR, Google Dataproc, Azure HDInsight
4. **Standalone**: Local Spark cluster

## 🔧 Configuration

Configuration files are located in the `config/` directory:

- `application.conf`: Main application configuration
- `dev.conf`: Development environment settings
- `prod.conf`: Production environment settings

## 📚 Documentation

- [Architecture Overview](docs/architecture.md)
- [API Documentation](docs/api.md)
- [Deployment Guide](docs/deployment.md)
- [Troubleshooting](docs/troubleshooting.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For questions and support:
- Check the [documentation](docs/)
- Review [troubleshooting guide](docs/troubleshooting.md)
- Open an issue on GitHub