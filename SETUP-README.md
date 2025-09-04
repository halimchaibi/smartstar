# SmartStar Development Environment Setup

This script provides a comprehensive setup for the SmartStar development environment, including all prerequisites, Docker services, and Spark applications.

## Quick Start

```bash
# Run complete setup (recommended)
./setup-dev-env.sh

# Run with help to see options
./setup-dev-env.sh --help

# Run with specific skips
./setup-dev-env.sh --skip-spark --skip-data
```

## What This Script Does

### 1. Prerequisites Installation
- **Java 11/17**: OpenJDK installation via package manager
- **Scala 2.13**: Scala runtime installation
- **SBT**: Scala Build Tool for compiling Spark applications
- **Docker**: Container runtime for infrastructure services
- **Python Dependencies**: paho-mqtt, faker for data generation

### 2. Infrastructure Setup
- **Docker Services**: Kafka, MQTT, PostgreSQL, MinIO, Kafka UI, Kafka Connect
- **Directory Structure**: Creates required volume directories with proper permissions
- **Configuration Files**: Sets up Kafka Connect and Mosquitto configurations

### 3. Service Initialization
- **Docker Compose**: Starts all services defined in `spark-apps/docker/docker-compose.yml`
- **Health Checks**: Waits for all services to become healthy
- **Kafka Topics**: Creates required topics for the data pipeline

### 4. Application Build
- **SBT Assembly**: Builds all Spark modules (common, ingestion, normalization, analytics)
- **Testing**: Runs the complete test suite
- **JAR Creation**: Generates fat JARs for job execution

### 5. Data Pipeline Verification
- **Sample Data**: Generates IoT sensor data using the Python generator
- **Job Execution**: Runs example ingestion, normalization, and analytics jobs
- **End-to-End Test**: Verifies the complete data flow

## Services Started

| Service | Port | Description |
|---------|------|-------------|
| Kafka | 9092 | Message broker |
| Kafka UI | 8080 | Web interface for Kafka |
| Kafka Connect | 8083 | Data integration platform |
| MQTT | 1883 | IoT message broker |
| PostgreSQL | 5432 | Relational database |
| MinIO | 9000, 9001 | Object storage |

## Directory Structure Created

```
spark-apps/docker/
├── kafka/
│   ├── data/           # Kafka data files
│   ├── logs/           # Kafka logs
│   ├── metadata/       # Kafka metadata
│   └── plugins/        # Kafka Connect plugins
├── mosquitto/
│   ├── data/           # MQTT persistence
│   └── logs/           # MQTT logs
├── postgres/
│   └── data/           # PostgreSQL data
└── minio/
    └── data/           # Object storage data
```

## Usage Examples

### Generate Sample Data
```bash
cd spark-apps/scripts
python3 sensor-data.generator.py --type sensors --duration 60 --devices 10
```

### Run Spark Jobs
```bash
cd spark-apps

# File ingestion
./scripts/run-job.sh ingestion com.smartstar.ingestion.batch.FileIngestionJob input/ output/

# Streaming ingestion  
./scripts/run-job.sh ingestion com.smartstar.ingestion.streaming.KafkaStreamingJob smartstar-events output/

# Data normalization
./scripts/run-job.sh normalization com.smartstar.normalization.cleaning.DataCleansingJob

# Analytics
./scripts/run-job.sh analytics com.smartstar.analytics.batch.AggregationJob
```

### Monitor Services
```bash
# View all container status
docker ps

# View logs
docker-compose logs -f kafka
docker-compose logs -f mosquitto

# Access Kafka UI
open http://localhost:8080
```

## Configuration Options

### Environment Variables
```bash
# Skip Spark installation (use system Spark)
INSTALL_SPARK=no ./setup-dev-env.sh

# Skip data generation
GENERATE_DATA=no ./setup-dev-env.sh

# Skip example job execution
RUN_EXAMPLES=no ./setup-dev-env.sh
```

### Command Line Options
```bash
# Skip components
./setup-dev-env.sh --skip-spark --skip-data --skip-examples

# View help
./setup-dev-env.sh --help
```

## Troubleshooting

### Common Issues

1. **Port Conflicts**: Ensure ports 5432, 8080, 8083, 9000, 9001, 9092, 1883 are free
2. **Docker Permission**: You may need to log out/in after Docker installation
3. **Memory**: Ensure at least 4GB RAM available for all services
4. **Java Version**: Java 8, 11, or 17 are recommended

### Service Health Checks
```bash
# Check service status
docker-compose ps

# Restart a service
docker-compose restart kafka

# View service logs
docker-compose logs service-name

# Cleanup and restart all
docker-compose down && docker-compose up -d
```

### Manual Service Testing
```bash
# Test Kafka
docker exec smartstar-kafka-broker /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

# Test MQTT
mosquitto_pub -h localhost -p 1883 -t test/topic -m "Hello MQTT"

# Test PostgreSQL
psql -h localhost -p 5432 -U smartstar -d smartstar

# Test MinIO
mc alias set local http://localhost:9000 minioadmin minioadmin
```

## Next Steps After Setup

1. **Explore Kafka UI**: Visit http://localhost:8080 to see topics and messages
2. **Generate Data**: Run the sensor data generator for extended periods
3. **Develop Jobs**: Create new Spark jobs in the modules
4. **Monitor Pipeline**: Use the provided monitoring tools
5. **Scale Services**: Adjust Docker Compose for production loads

## Cleanup

```bash
# Stop all services
cd spark-apps/docker
docker-compose down

# Remove all data (optional)
./cleanup.sh all

# Remove Docker images (optional)
docker-compose down --rmi all --volumes
```

## Support

- Check logs: `docker-compose logs -f [service]`
- Restart services: `docker-compose restart [service]`  
- Full reset: `docker-compose down && ./cleanup.sh all && ./setup-dev-env.sh`
- Issues: See project README.md or create GitHub issues