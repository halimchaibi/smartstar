# SmartStar - IoT Data Platform

A comprehensive data lakehouse platform for IoT sensor data, built with Apache Spark, Kafka, and the Medallion Architecture (Bronze → Silver → Gold).

## 🎯 Overview

SmartStar is designed to process high-volume IoT sensor data through a modern streaming architecture:

```
IoT Sensors → MQTT → Kafka → Spark → Iceberg Tables → Analytics
              ↑                         ↑
          Mosquitto              MinIO (S3-compatible)
```

## ✨ Features

- **Real-time IoT Data Ingestion**: MQTT → Kafka streaming pipeline
- **Medallion Architecture**: Bronze (raw), Silver (cleansed), Gold (aggregated)
- **Schema Management**: Confluent Schema Registry (Avro, JSON Schema, Protobuf)
- **Data Lakehouse**: Apache Iceberg tables on MinIO (S3-compatible)
- **Spark 4.0 + Spark Connect**: Modern distributed processing
- **One-Click Dev Environment**: Complete Docker-based development stack
- **Comprehensive Monitoring**: Kafka UI, MinIO Console, health checks

## 📁 Project Structure

```
smartstar/
├── setup-dev-env.sh              # 🚀 One-click dev environment setup
├── infrastructure/
│   └── docker/
│       ├── docker-compose.yml    # All services (Kafka, MinIO, etc.)
│       ├── mosquitto/            # MQTT broker config
│       ├── postgres/             # PostgreSQL init scripts
│       └── kafka-connect/        # Connectors and plugins
├── spark-apps/                   # Scala Spark applications
│   ├── common/                   # Shared utilities
│   ├── ingestion-app/            # Kafka → Bronze layer
│   ├── normalization-app/        # Bronze → Silver layer
│   ├── analytics-app/            # Silver → Gold layer
│   └── dev-tools/                # Development utilities
│       └── sensor-data.generator.py  # IoT data simulator
├── scripts/                      # Utility scripts
├── api-services/                 # REST APIs
├── data-pipelines/               # Airflow, Argo, Prefect
├── monitoring/                   # Prometheus, Grafana, Jaeger
├── tests/                        # E2E, integration, performance tests
└── docs/                         # Documentation
```

## 🛠️ Prerequisites

| Component | Version | Required |
|-----------|---------|----------|
| Docker | 24+ | ✅ Yes |
| Docker Compose | 2.x | ✅ Yes |
| Java | 21 | For Spark apps |
| Scala | 2.13.x | For Spark apps |
| SBT | 1.9.x | For building |
| Python | 3.13+ | For data generator |
| pyenv | Latest | Recommended |

## 🚀 Quick Start

### 0. Setup Python Environment (First Time)

```bash
# The project uses Python 3.13+ with pyenv
# A .python-version file is included

# Create virtual environment
python -m venv .venv

# Activate it
source .venv/bin/activate  # Linux/Mac
# .venv\Scripts\activate   # Windows

# Install dependencies
pip install -r requirements.txt

# Or install just the essentials
pip install paho-mqtt faker requests
```

### 1. Start Development Environment

```bash
# Clone the repository
git clone https://github.com/your-org/smartstar.git
cd smartstar

# Start all services with one command
./setup-dev-env.sh start
```

This starts:
- **Kafka** (KRaft mode) - Message streaming
- **Schema Registry** - Schema management
- **Kafka Connect** - Connectors framework
- **Kafka UI** - Web interface
- **MinIO** - S3-compatible storage
- **PostgreSQL** - Iceberg catalog
- **Mosquitto** - MQTT broker

### 2. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Kafka UI | http://localhost:8080 | - |
| Schema Registry | http://localhost:8081 | - |
| MinIO Console | http://localhost:9001 | minioadmin / minioadmin |
| Kafka Connect | http://localhost:8083 | - |
| PostgreSQL | localhost:5432 | smartstar / smartstar |
| MQTT Broker | localhost:1883 | - |
| Kafka Bootstrap | localhost:9094 | - |

### 3. Generate Test Data

```bash
# Activate Python virtual environment (if not already)
source .venv/bin/activate

# Generate IoT sensor data for 60 seconds
python spark-apps/dev-tools/sensor-data.generator.py \
    --broker localhost \
    --port 1883 \
    --type sensors \
    --duration 60 \
    --devices 5
```

### 4. Build & Run Spark Applications

```bash
cd spark-apps
sbt clean assembly
```

See [spark-apps/README.md](spark-apps/README.md) for detailed instructions on running the Spark streaming jobs.

**Quick start:**

```bash
# Run Kafka → Bronze ingestion job in Docker
docker run --rm --network smartstar \
  -v $(pwd)/spark-apps/modules/ingestion/target/scala-2.13:/app \
  -e AWS_ACCESS_KEY_ID=minioadmin -e AWS_SECRET_ACCESS_KEY=minioadmin \
  -e AWS_REGION=us-east-1 -e ENV=development \
  eclipse-temurin:21-jdk \
  java -cp /app/smartstar-ingestion-assembly-1.0.0.jar \
    com.smartstar.ingestion.streaming.KafkaStreamingJob
```

## 📊 Data Pipeline

### Sensor Types

| Type | Metrics | Topic |
|------|---------|-------|
| Temperature | temperature, humidity | `sensors.temperature` |
| Air Quality | pm25, pm10, co2, aqi | `sensors.air_quality` |
| Motion | motion_detected, confidence | `sensors.motion` |
| Smart Meter | power, voltage, current | `sensors.smart_meter` |
| Weather | temperature, pressure, wind | `sensors.weather` |
| Vehicle | speed, fuel, engine_temp | `sensors.vehicle` |

### Data Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   MQTT      │────▶│   Kafka     │────▶│   Bronze    │────▶│   Silver    │
│  Sensors    │     │   Topics    │     │   (JSON)    │     │  (Parquet)  │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                           │                                       │
                           ▼                                       ▼
                    ┌─────────────┐                         ┌─────────────┐
                    │   Schema    │                         │    Gold     │
                    │  Registry   │                         │ (Iceberg)   │
                    └─────────────┘                         └─────────────┘
```

### Storage Layout (MinIO/S3)

```
s3://smartstar/
├── bronze/           # Raw JSON from Kafka
│   └── sensors/
│       └── topic=sensors.temperature/
│           └── year=2025/month=12/day=01/
├── silver/           # Cleansed Parquet/Iceberg
│   └── sensors/
└── gold/             # Aggregated analytics
```

## 🔧 Setup Commands

```bash
# Interactive menu
./setup-dev-env.sh

# Start services only (quick)
./setup-dev-env.sh start

# Full setup (install deps + start)
./setup-dev-env.sh setup

# Complete setup (full + connectors)
./setup-dev-env.sh complete

# Stop all services
./setup-dev-env.sh stop

# Check service status
./setup-dev-env.sh status

# View logs
./setup-dev-env.sh logs

# Check environment health
./setup-dev-env.sh health

# Remove everything (volumes too)
./setup-dev-env.sh clean

# Test individual function
./setup-dev-env.sh test create_kafka_topics
```

## 🏗️ Building & Running Spark Jobs

### Build All Modules

```bash
cd spark-apps
sbt clean assembly
```

### Run Ingestion Job

```bash
# Using Spark Connect
java -jar ingestion-app/target/scala-2.13/ingestion-job.jar

# Or submit to Spark cluster
spark-submit \
    --class com.smartstar.ingestion.IngestionJob \
    --master spark://localhost:7077 \
    ingestion-app/target/scala-2.13/ingestion-job.jar
```

### Configuration

Edit `spark-apps/*/src/main/resources/application.conf`:

```hocon
kafka {
  bootstrap.servers = "localhost:9094"
  topics = "sensors.temperature,sensors.motion,sensors.air_quality"
}

ingestion {
  bronze.base.path = "s3a://smartstar/bronze/sensors"
  checkpoint.base.path = "s3a://smartstar/checkpoints"
}
```

## 🔌 MQTT Kafka Connector

The platform includes a pre-configured MQTT-to-Kafka connector that bridges IoT sensor data from Mosquitto to Kafka topics.

### Connector Status

```bash
# Check connector status
curl -s http://localhost:8083/connectors/mqtt-source-sensors/status | jq

# List all connectors
curl -s http://localhost:8083/connectors | jq
```

### Connector Configuration

| Setting | Value |
|---------|-------|
| Name | `mqtt-source-sensors` |
| MQTT Broker | `tcp://smartstar-mosquitto:1883` |
| Source Topics | `sensors/temperature/+`, `sensors/air_quality/+`, `sensors/motion/+` |
| Kafka Topics | `sensors.temperature`, `sensors.air_quality`, `sensors.motion` |

### Manage Connector

```bash
# Pause connector
curl -X PUT http://localhost:8083/connectors/mqtt-source-sensors/pause

# Resume connector
curl -X PUT http://localhost:8083/connectors/mqtt-source-sensors/resume

# Restart connector
curl -X POST http://localhost:8083/connectors/mqtt-source-sensors/restart

# Delete connector
curl -X DELETE http://localhost:8083/connectors/mqtt-source-sensors

# Re-create connector
./setup-dev-env.sh test init_mqtt_connector
```

### Data Flow

```
MQTT Topic                    →  Kafka Topic
─────────────────────────────────────────────
sensors/temperature/{device}  →  sensors.temperature
sensors/air_quality/{device}  →  sensors.air_quality
sensors/motion/{device}       →  sensors.motion
```

---

## 📈 Schema Registry

### Register a Schema

```bash
# Register Avro schema for temperature sensor
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{
    "schema": "{\"type\":\"record\",\"name\":\"Temperature\",\"fields\":[{\"name\":\"device_id\",\"type\":\"string\"},{\"name\":\"temperature\",\"type\":\"double\"},{\"name\":\"humidity\",\"type\":\"double\"},{\"name\":\"timestamp\",\"type\":\"string\"}]}"
  }' \
  http://localhost:8081/subjects/sensors.temperature-value/versions
```

### List Schemas

```bash
curl http://localhost:8081/subjects
```

## 🐳 Docker Services

All services are defined in `infrastructure/docker/docker-compose.yml`:

| Service | Image | Description |
|---------|-------|-------------|
| kafka | apache/kafka:4.0.0 | Kafka broker (KRaft mode) |
| schema-registry | confluentinc/cp-schema-registry:7.6.0 | Schema management |
| kafka-ui | provectuslabs/kafka-ui | Web UI for Kafka |
| kafka-connect | apache/kafka:4.0.0 | Connector framework + MQTT plugin |
| minio | minio/minio | S3-compatible storage |
| postgres | postgres:16-alpine | Iceberg catalog |
| mosquitto | eclipse-mosquitto:2.0 | MQTT broker |

### Auto-configured Components

When running `./setup-dev-env.sh start`:
- **8 Kafka topics** created (sensors.*, events.*)
- **5 MinIO buckets** created (smartstar, bronze, silver, gold, checkpoints)
- **MQTT connector plugin** installed (Lenses Stream Reactor)

When running `./setup-dev-env.sh complete`:
- All of the above, plus:
- **MQTT-Kafka connector** configured and running

## 🧪 Testing

```bash
# Run unit tests
cd spark-apps
sbt test

# Run integration tests
sbt "testOnly *IntegrationTest"

# Generate test coverage
sbt coverage test coverageReport
```

## 📚 Additional Resources

- [Architecture Documentation](docs/architecture/)
- [API Reference](docs/api/)
- [Deployment Guide](docs/deployment/)
- [User Guides](docs/user-guides/)

## 🔧 Troubleshooting

### Port Already in Use

```bash
# Find and kill process on port
sudo lsof -i :5432
sudo kill -9 <PID>

# Or disable system PostgreSQL
sudo systemctl stop postgresql
sudo systemctl disable postgresql
```

### Kafka Connect Unhealthy

The `apache/kafka` image doesn't have `curl`, so health checks use bash TCP:

```yaml
healthcheck:
  test: ["CMD-SHELL", "bash -c 'echo > /dev/tcp/localhost/8083'"]
```

### Reset Environment

```bash
./setup-dev-env.sh clean
./setup-dev-env.sh start
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏷️ Version

- **Platform**: SmartStar 2.0
- **Spark**: 4.0.0
- **Scala**: 2.13.16
- **Kafka**: 4.0.0 (KRaft)
- **Iceberg**: 1.10.0
