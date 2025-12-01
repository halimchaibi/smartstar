# SmartStar Spark Applications

Multi-module Spark project for the IoT data processing pipeline (Medallion Architecture).

## 📁 Structure

```
spark-apps/
├── modules/
│   ├── common/          # Shared utilities, configs, traits
│   ├── ingestion/       # Kafka → Bronze layer
│   ├── normalization/   # Bronze → Silver layer
│   └── analytics/       # Silver → Gold layer
├── config/              # Environment-specific configs
├── dev-tools/           # Development utilities
│   ├── sensor-data.generator.py  # IoT data simulator
│   └── run-apps.sh      # App runner script
└── build.sbt            # SBT build definition
```

## 🛠️ Prerequisites

| Component | Version |
|-----------|---------|
| Java | 21+ |
| Scala | 2.13.16 |
| SBT | 1.9.x |
| Docker | 24+ (for running) |

## 🔨 Build

```bash
cd spark-apps

# Build all modules
sbt clean assembly

# Build specific module
sbt "project ingestion" assembly
sbt "project normalization" assembly
sbt "project analytics" assembly
```

## 🚀 Run Spark Streaming Jobs

### Ingestion Job (Kafka → Bronze)

The ingestion job reads sensor data from Kafka topics and writes to the Bronze layer in MinIO as partitioned JSON files.

#### Run in Docker (Recommended)

```bash
# From the smartstar root directory
docker run --rm --network smartstar \
  -v $(pwd)/spark-apps/modules/ingestion/target/scala-2.13:/app \
  -e AWS_ACCESS_KEY_ID=minioadmin \
  -e AWS_SECRET_ACCESS_KEY=minioadmin \
  -e AWS_REGION=us-east-1 \
  -e ENV=development \
  eclipse-temurin:21-jdk \
  java -cp /app/smartstar-ingestion-assembly-1.0.0.jar \
    com.smartstar.ingestion.streaming.KafkaStreamingJob
```

#### Run Locally

Requires Docker hostnames in `/etc/hosts`:

```bash
# Add hostname mappings (one-time)
echo "127.0.0.1 smartstar-kafka smartstar-minio" | sudo tee -a /etc/hosts

# Set environment variables
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
export KAFKA_BOOTSTRAP_SERVERS=localhost:9094
export MINIO_ENDPOINT=http://localhost:9000/

# Run the job
java -cp modules/ingestion/target/scala-2.13/smartstar-ingestion-assembly-1.0.0.jar \
  com.smartstar.ingestion.streaming.KafkaStreamingJob
```

### Normalization Job (Bronze → Silver)

```bash
docker run --rm --network smartstar \
  -v $(pwd)/spark-apps/modules/normalization/target/scala-2.13:/app \
  -e AWS_ACCESS_KEY_ID=minioadmin \
  -e AWS_SECRET_ACCESS_KEY=minioadmin \
  -e ENV=development \
  eclipse-temurin:21-jdk \
  java -cp /app/smartstar-normalization-assembly-1.0.0.jar \
    com.smartstar.normalization.streaming.S3StreamingJob
```

### Analytics Job (Silver → Gold)

```bash
docker run --rm --network smartstar \
  -v $(pwd)/spark-apps/modules/analytics/target/scala-2.13:/app \
  -e AWS_ACCESS_KEY_ID=minioadmin \
  -e AWS_SECRET_ACCESS_KEY=minioadmin \
  -e ENV=development \
  eclipse-temurin:21-jdk \
  java -cp /app/smartstar-analytics-assembly-1.0.0.jar \
    com.smartstar.analytics.AnalyticsJob
```

## ✅ Verify Data Pipeline

### Check Bronze Layer

```bash
# List files in Bronze layer
docker exec smartstar-minio mc ls --recursive myminio/smartstar/development/bronze/sensors/

# View sample data
docker exec smartstar-minio mc cat "myminio/smartstar/development/bronze/sensors/topic=sensors.temperature/year=2025/month=12/day=1/" | head -5
```

### Check Kafka Topics

```bash
# List messages in a topic
docker exec smartstar-kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic sensors.temperature \
  --from-beginning --max-messages 5
```

## ⚙️ Configuration

Configuration is loaded from `development.conf` (or `production.conf`, `staging.conf` based on `ENV`).

### Key Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ENV` | Environment (development/staging/production) | development |
| `AWS_ACCESS_KEY_ID` | MinIO/S3 access key | - |
| `AWS_SECRET_ACCESS_KEY` | MinIO/S3 secret key | - |
| `KAFKA_BOOTSTRAP_SERVERS` | Kafka broker address | smartstar-kafka:9092 |
| `MINIO_ENDPOINT` | MinIO/S3 endpoint URL | http://smartstar-minio:9000/ |

### Kafka Topics

| Topic | Description |
|-------|-------------|
| `sensors.temperature` | Temperature sensor readings |
| `sensors.air_quality` | Air quality measurements |
| `sensors.motion` | Motion detection events |

## 📊 Output Schema (Bronze Layer)

```json
{
  "value": "{\"device_id\": \"...\", \"sensor_type\": \"temperature\", ...}",
  "topic": "sensors.temperature",
  "partition": 0,
  "offset": 123,
  "timestamp": "2025-12-01T22:08:54.105Z",
  "kafka_timestamp": "2025-12-01T22:08:54.105Z",
  "ingestion_ts": "2025-12-01T22:08:54.159Z",
  "event_time": "2025-12-01T22:08:54.097Z",
  "year": 2025,
  "month": 12,
  "day": 1
}
```

## 🧪 Testing

```bash
# Run all tests
sbt test

# Run specific module tests
sbt "project ingestion" test
sbt "project common" test
```

## 📝 Development

### Using SBT Console

```bash
sbt
> project ingestion
> run
> test
> assembly
```

### Hot Reload (Development)

```bash
sbt ~compile  # Continuous compilation
```
