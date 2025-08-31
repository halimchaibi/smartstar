# SmartStar - Complete Data Platform

A comprehensive enterprise data platform built with Apache Spark and Scala, featuring data ingestion, normalization, and advanced analytics capabilities.

## 🚀 Features

- **Data Ingestion**: Batch and streaming ingestion from multiple sources
- **Data Normalization**: Automated data cleansing, validation, and transformation
- **Analytics**: Advanced analytics, machine learning, and real-time processing
- **Modular Architecture**: Clean separation of concerns with reusable components
- **Production Ready**: Enterprise-grade configurations and monitoring

## 📁 Project Structure

```
smartstar/
├── spark-apps/                    # Scala Spark applications
│   ├── modules/
│   │   ├── common/                # Shared utilities and configurations
│   │   ├── ingestion/             # Data ingestion jobs
│   │   ├── normalization/         # Data cleansing and transformation
│   │   └── analytics/             # Analytics and ML workloads
│   └── scripts/                   # Build and deployment scripts
├── config/                        # Environment-specific configurations
├── infrastructure/                # Infrastructure as Code (Terraform, K8s)
├── data-pipelines/               # Workflow orchestration (Airflow)
├── monitoring/                   # Observability stack (Prometheus, Grafana)
└── docs/                         # Documentation
```

## 🛠️ Prerequisites

- **Java**: 8 or 11
- **Scala**: 2.13.x
- **SBT**: 1.9.x
- **Apache Spark**: 3.5.x
- **Docker** (optional, for local development)

## 🚀 Quick Start

### 1. Build the Project

```bash
cd spark-apps
./scripts/build.sh
```

### 2. Run Example Jobs

```bash
# File ingestion job
./scripts/run-job.sh ingestion com.smartstar.ingestion.batch.FileIngestionJob input/ output/

# Data cleansing job  
./scripts/run-job.sh normalization com.smartstar.normalization.cleaning.DataCleansingJob

# Analytics aggregation job
./scripts/run-job.sh analytics com.smartstar.analytics.batch.AggregationJob
```

### 3. Start Local Development Environment (Optional)

```bash
cd spark-apps/docker
docker-compose up -d
```

This starts:
- Spark cluster (master + worker)
- PostgreSQL database
- Kafka + Zookeeper

## 🏗️ Development

### Building Individual Modules

```bash
cd spark-apps

# Build specific module
sbt "project common" compile
sbt "project ingestion" compile
sbt "project normalization" compile  
sbt "project analytics" compile
```

### Running Tests

```bash
# All tests
sbt test

# Module-specific tests
sbt "project common" test
```

### Code Quality

```bash
# Format code
sbt scalafmt

# Check style
sbt scalastyle
```

### Creating Fat JARs

```bash
# All modules
sbt assembly

# Specific module
sbt "project ingestion" assembly
```

## 📊 Available Jobs

### Ingestion Jobs
- `FileIngestionJob`: Batch file processing (CSV, JSON, Parquet)
- `DatabaseIngestionJob`: Database extraction via JDBC
- `KafkaStreamingJob`: Real-time Kafka stream processing
- `ApiIngestionJob`: REST API data extraction

### Normalization Jobs
- `DataCleansingJob`: Data quality validation and cleansing
- `DataTransformationJob`: Schema transformation and mapping
- `DeduplicationJob`: Duplicate record removal
- `DataEnrichmentJob`: Reference data joining and enrichment

### Analytics Jobs
- `AggregationJob`: Time-based data aggregations
- `FeatureEngineeringJob`: ML feature preparation
- `ModelTrainingJob`: Machine learning model training
- `RealTimeAnalyticsJob`: Streaming analytics and alerting

## ⚙️ Configuration

### Environment-Specific Configs

```bash
config/
├── environments/
│   ├── development/application.conf
│   ├── staging/application.conf
│   └── production/application.conf
```

### Application Configuration

Main configuration in `spark-apps/modules/common/src/main/resources/application.conf`:

```hocon
app {
  name = "smartstar-spark-app"
  version = "1.0.0"
}

spark {
  master = "local[*]"
  executor {
    memory = "2g" 
    cores = 2
  }
}

database {
  url = "jdbc:postgresql://localhost:5432/smartstar"
  username = "smartstar_user"
  password = "smartstar_password"
}
```

## 🚀 Deployment

### Local Deployment

```bash
# Build and run locally
./scripts/build.sh
./scripts/run-job.sh [module] [job-class] [args...]
```

### Cluster Deployment

```bash
# Submit to YARN cluster
spark-submit \
  --class com.smartstar.ingestion.batch.FileIngestionJob \
  --master yarn \
  --deploy-mode cluster \
  target/scala-2.13/smartstar-ingestion-assembly-1.0.0.jar \
  s3://input-bucket/ s3://output-bucket/
```

### Docker Deployment

```bash
cd spark-apps/docker
docker-compose up -d
```

## 📈 Monitoring

The project includes comprehensive monitoring setup:

- **Metrics**: Prometheus + Grafana dashboards
- **Logging**: Centralized logging with ELK stack
- **Tracing**: Distributed tracing with Jaeger
- **Alerting**: Custom alerts for job failures and performance issues

## 🧪 Testing

### Unit Tests

```bash
sbt test
```

### Integration Tests

```bash
sbt "testOnly *IntegrationTest"
```

### End-to-End Tests

```bash
cd tests/e2e
./run-e2e-tests.sh
```

## 📚 Documentation

Detailed documentation available in the `docs/` directory:

- [Architecture Overview](docs/architecture/system-architecture.md)
- [API Documentation](docs/api/)
- [Deployment Guide](docs/deployment/)
- [User Guides](docs/user-guides/)

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

For issues and questions:

1. Check the [documentation](docs/)
2. Search existing [GitHub issues](../../issues)
3. Create a new issue with detailed information

## 🏷️ Version History

- **1.0.0**: Initial release with ingestion, normalization, and analytics modules
- Core Spark 3.5.0 support
- Scala 2.13 compatibility
- Docker and Kubernetes deployment support
