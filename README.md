# SmartStar - Complete Data Platform

A comprehensive enterprise data platform built with Apache Spark and Scala, featuring data ingestion, normalization, and advanced analytics capabilities.

## 🚀 Features

- **Data Ingestion**: Batch and streaming ingestion from multiple sources
- **Data Normalization**: Automated data cleansing, validation, and transformation
- **Analytics**: Advanced analytics, machine learning, and real-time processing
- **API Services**: RESTful APIs for data access, metadata management, and monitoring
- **Web UI**: Interactive dashboards, admin panels, and data exploration interfaces
- **Workflow Orchestration**: Multiple orchestration engines (Airflow, Argo, Prefect)
- **Infrastructure as Code**: Terraform and Kubernetes deployment automation
- **Comprehensive Monitoring**: Full observability with metrics, logs, and tracing
- **Testing Framework**: End-to-end, integration, performance, and data quality testing
- **Development Tools**: CI/CD pipelines, code quality tools, and local development setup
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
│   ├── scripts/                   # Build and deployment scripts
│   ├── config/                    # Spark app configurations
│   │   ├── environments/          # Environment-specific configs
│   │   └── modules/               # Module-specific configs
│   └── docker/                    # Docker development environment
├── api-services/                  # REST APIs and microservices
│   ├── data-api/                  # Data access and query API
│   ├── metadata-api/              # Data catalog and metadata service
│   └── monitoring-api/            # Monitoring and metrics API
├── web-ui/                        # Web-based user interfaces
│   ├── admin-panel/               # Administrative interface
│   ├── dashboard/                 # Analytics and monitoring dashboard
│   └── data-explorer/             # Interactive data exploration UI
├── data-pipelines/                # Workflow orchestration
│   ├── airflow/                   # Apache Airflow DAGs and configs
│   ├── argo-workflows/            # Kubernetes-native workflows
│   └── prefect/                   # Modern workflow orchestration
├── infrastructure/                # Infrastructure as Code
│   ├── terraform/                 # Terraform modules and environments
│   ├── kubernetes/                # K8s manifests, Helm charts, operators
│   └── docker/                    # Container configurations
├── monitoring/                    # Observability stack
│   ├── prometheus/                # Metrics collection and alerting
│   ├── grafana/                   # Dashboards and visualization
│   ├── jaeger/                    # Distributed tracing
│   └── elasticsearch/             # Log aggregation and search
├── tests/                         # Testing infrastructure
│   ├── e2e/                       # End-to-end tests
│   ├── integration/               # Integration tests
│   ├── performance/               # Performance and load tests
│   └── data-quality/              # Data quality validation tests
├── tools/                         # Development and operational tools
│   ├── ci-cd/                     # CI/CD pipeline configurations
│   ├── code-quality/              # Linting, formatting, analysis tools
│   └── local-dev/                 # Local development environment setup
├── scripts/                       # Utility and automation scripts
│   ├── setup/                     # Environment setup scripts
│   ├── deployment/                # Deployment automation
│   └── utilities/                 # General utility scripts
└── docs/                          # Documentation
    ├── architecture/              # System design and architecture docs
    ├── api/                       # API documentation
    ├── deployment/                # Deployment guides
    └── user-guides/               # User manuals and tutorials
```

## 🛠️ Prerequisites

### Core Requirements
- **Java**: 8 or 11
- **Scala**: 2.13.x
- **SBT**: 1.9.x
- **Apache Spark**: 3.5.x

### Optional Components
- **Docker** & **Docker Compose**: For containerized development
- **Kubernetes**: For orchestration and deployment
- **Terraform**: For infrastructure provisioning
- **Node.js**: For web UI development
- **Python**: For certain data pipeline components

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
cd infrastructure/docker
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

## 🌐 API Services

The platform provides RESTful APIs for programmatic access:

### Data API (`api-services/data-api/`)
- Query and retrieve processed data
- Real-time data access endpoints
- Data export functionality

### Metadata API (`api-services/metadata-api/`)
- Data catalog and schema registry
- Lineage tracking and data discovery
- Dataset metadata management

### Monitoring API (`api-services/monitoring-api/`)
- System health and performance metrics
- Job status and execution monitoring
- Alert management and notifications

## 💻 Web User Interface

Interactive web interfaces for platform management:

### Admin Panel (`web-ui/admin-panel/`)
- User and permission management
- System configuration and settings
- Resource monitoring and allocation

### Analytics Dashboard (`web-ui/dashboard/`)
- Real-time metrics and KPIs
- Custom visualization and reporting
- Data pipeline monitoring

### Data Explorer (`web-ui/data-explorer/`)
- Interactive data browsing and querying
- Schema exploration and profiling
- Ad-hoc analysis and visualization

## 🔄 Workflow Orchestration

Multiple orchestration engines supported:

### Apache Airflow (`data-pipelines/airflow/`)
```bash
cd data-pipelines/airflow
# Start Airflow webserver and scheduler
docker-compose up -d
```

### Argo Workflows (`data-pipelines/argo-workflows/`)
```bash
# Deploy workflows to Kubernetes
kubectl apply -f data-pipelines/argo-workflows/
```

### Prefect (`data-pipelines/prefect/`)
```bash
cd data-pipelines/prefect
# Start Prefect server
prefect server start
```

## ⚙️ Configuration

SmartStar uses a **hierarchical configuration system** that provides consistent, environment-aware configuration management across all modules.

### Configuration Hierarchy

Configuration is loaded in the following order (later overrides earlier):

1. **Base Configuration**: `modules/common/src/main/resources/application.conf`
2. **Common Settings**: `config/common.conf`
3. **Environment-Specific**: `config/environments/{environment}.conf`
4. **Module-Specific**: `config/modules/{module}.conf`
5. **Environment Variables**: Runtime overrides

### Directory Structure

```bash
spark-apps/config/
├── common.conf                    # Shared configuration across all modules
├── environments/
│   ├── development.conf          # Development environment settings
│   ├── test.conf                 # Test environment settings
│   ├── staging.conf              # Staging environment settings
│   └── production.conf           # Production environment settings
└── modules/
    ├── analytics.conf            # Analytics module specific settings
    ├── ingestion.conf            # Ingestion module specific settings
    └── normalization.conf        # Normalization module specific settings
```

### Environment Detection

The system automatically detects the environment from:
1. System property: `-Denvironment=production`
2. Environment variables: `ENVIRONMENT`, `ENV`, `SPARK_ENV`
3. Default: `development`

### Usage in Applications

```scala
import com.smartstar.common.config.ConfigurationFactory

// Recommended: Module-specific configuration
class MyIngestionJob extends SparkJob with ConfigurableJob {
  override def config: AppConfig = ConfigurationFactory.forModule("ingestion")
}

// Alternative: Explicit environment
val config = ConfigurationFactory.forEnvironment(Environment.Production)

// For testing
val testConfig = ConfigurationFactory.forTesting("my-test")
```

### Configuration Validation

Validate all configurations:

```bash
cd spark-apps
sbt "runMain com.smartstar.tools.ConfigurationValidator"
```

### Environment-Specific Examples

**Development**:
```hocon
spark.master = "local[*]"
database.host = "localhost"
storage.base-path = "/tmp/smartstar/dev"
```

**Production**:
```hocon
spark.master = "yarn"
database.host = "prod-postgres-cluster.internal"
storage.base-path = "s3a://smartstar-prod-bucket/data"
```

### Module-Specific Examples

**Ingestion**:
```hocon
kafka.topics.raw-data = "smartstar-raw-data"
data-quality.fail-on-error = true
```

**Analytics**:
```hocon
spark.sql.shuffle-partitions = 400
ml.feature-store.enabled = true
```

For detailed configuration documentation, see: [Configuration System Guide](docs/configuration-system.md)

## 🚀 Deployment

### Local Deployment

```bash
# Build and run locally
cd spark-apps
./scripts/build.sh
./scripts/run-job.sh [module] [job-class] [args...]
```

### Infrastructure Deployment

#### Using Terraform
```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

#### Using Kubernetes
```bash
cd infrastructure/kubernetes
kubectl apply -f manifests/
```

#### Using Helm Charts
```bash
cd infrastructure/kubernetes/helm-charts
helm install smartstar ./smartstar-chart
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
cd infrastructure/docker
docker-compose up -d
```

### Environment Setup

```bash
# Initial environment setup
./scripts/setup-v2.sh

# Or use the setup directory
cd scripts/setup
./bootstrap.sh
```

## 📈 Monitoring

The project includes comprehensive monitoring setup:

- **Metrics**: Prometheus + Grafana dashboards (`monitoring/prometheus/`, `monitoring/grafana/`)
- **Logging**: Centralized logging with ELK stack (`monitoring/elasticsearch/`)
- **Tracing**: Distributed tracing with Jaeger (`monitoring/jaeger/`)
- **Alerting**: Custom alerts for job failures and performance issues

### Starting the Monitoring Stack

```bash
cd monitoring
docker-compose up -d
```

Access points:
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Jaeger UI: http://localhost:16686

## 🧪 Testing

### Unit Tests

```bash
cd spark-apps
sbt test
```

### Integration Tests

```bash
cd spark-apps
sbt "testOnly *IntegrationTest"
```

### Test Infrastructure

The project includes comprehensive testing framework structure:

- `tests/e2e/`: End-to-end testing infrastructure
- `tests/integration/`: Integration test suites
- `tests/performance/`: Performance and load testing
- `tests/data-quality/`: Data quality validation tests

*Note: Test implementations are currently being developed in their respective directories.*

## 🛠️ Development Tools

### CI/CD Pipelines (`tools/ci-cd/`)
- GitHub Actions workflows
- GitLab CI configurations  
- Jenkins pipeline scripts

### Code Quality (`tools/code-quality/`)
- Linting and formatting configurations
- Static analysis tools
- Code coverage reporting

### Local Development (`tools/local-dev/`)
- Development environment setup
- IDE configurations
- Testing utilities

## 📚 Documentation

Detailed documentation available in the `docs/` directory:

- [Architecture Overview](docs/architecture/)
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

This project is licensed under the MIT License.

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
