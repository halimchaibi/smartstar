#!/bin/bash

# SmartStar Quick Start Script
# Minimal setup to get the development environment running quickly
# This assumes Docker is already installed

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/spark-apps/docker"

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║             SmartStar Quick Start                        ║"
echo "║             Get up and running in minutes                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Check prerequisites
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

log_info "Setting up Docker environment..."

cd "$DOCKER_DIR"

# Create necessary directories
log_info "Creating volume directories..."
mkdir -p kafka/data zookeeper/data zookeeper/logs
mkdir -p mosquitto/data mosquitto/logs  
mkdir -p postgres/data
mkdir -p minio/data

# Set permissions for new directories only
chmod 755 kafka zookeeper mosquitto postgres minio 2>/dev/null || true
find kafka zookeeper mosquitto postgres minio -type d -exec chmod 755 {} \; 2>/dev/null || true

# Create Kafka Connect config if needed
if [ ! -f "kafka/connect-distributed.properties" ]; then
    log_info "Creating Kafka Connect configuration..."
    cat > kafka/connect-distributed.properties << 'EOF'
bootstrap.servers=localhost:9092
group.id=external-connect-cluster
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=false
value.converter.schemas.enable=false
offset.storage.topic=_connect-offsets
offset.storage.replication.factor=1
config.storage.topic=_connect-configs
config.storage.replication.factor=1
status.storage.topic=_connect-status
status.storage.replication.factor=1
rest.port=8083
plugin.path=/etc/kafka-connect/plugins
EOF
fi

# Ensure Mosquitto config exists
if [ ! -f "mosquitto/config/mosquitto.conf" ]; then
    log_info "Creating Mosquitto configuration..."
    mkdir -p mosquitto/config
    cat > mosquitto/config/mosquitto.conf << 'EOF'
listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/logs/mosquitto.log
log_type all
connection_messages true
log_timestamp true
EOF
fi

log_success "Docker environment configured"

# Start services
log_info "Starting Docker services..."
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi

$DOCKER_COMPOSE -f docker-compose-simple.yml down &> /dev/null || true
$DOCKER_COMPOSE -f docker-compose-simple.yml up -d

log_info "Waiting for services to start..."
sleep 20

# Check if services are running
if docker ps | grep -q smartstar-kafka-broker; then
    log_success "Kafka is running"
else
    log_error "Kafka failed to start"
    exit 1
fi

if docker ps | grep -q smartstar-postgres; then
    log_success "PostgreSQL is running"
else
    log_error "PostgreSQL failed to start"
    exit 1
fi

# Create basic Kafka topics
log_info "Creating Kafka topics..."
sleep 10

docker exec smartstar-kafka-broker /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --create --topic smartstar-events --partitions 3 --replication-factor 1 --if-not-exists &> /dev/null

docker exec smartstar-kafka-broker /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --create --topic sensors.temperature --partitions 3 --replication-factor 1 --if-not-exists &> /dev/null

docker exec smartstar-kafka-broker /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --create --topic sensors.air_quality --partitions 3 --replication-factor 1 --if-not-exists &> /dev/null

log_success "Kafka topics created"

echo -e "\n${GREEN}🎉 SmartStar Services Are Running!${NC}\n"

echo -e "${BLUE}📊 Service Status:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep smartstar

echo -e "\n${BLUE}🌐 Access URLs:${NC}"
echo -e "  • Kafka UI: ${GREEN}http://localhost:8080${NC}"
echo -e "  • MinIO Console: ${GREEN}http://localhost:9001${NC} (admin/minioadmin)"  
echo -e "  • PostgreSQL: ${GREEN}localhost:5432${NC} (smartstar/smartstar)"
echo -e "  • MQTT Broker: ${GREEN}localhost:1883${NC}"

echo -e "\n${BLUE}🚀 Next Steps:${NC}"
echo -e "1. Install Java, Scala, SBT if not already installed"
echo -e "2. Build the applications:"
echo -e "   ${YELLOW}cd spark-apps && ./scripts/build.sh${NC}"
echo -e "3. Generate sample data:"
echo -e "   ${YELLOW}cd spark-apps/scripts && python3 sensor-data.generator.py --duration 60${NC}"
echo -e "4. Run jobs:"
echo -e "   ${YELLOW}cd spark-apps && ./scripts/run-job.sh ingestion com.smartstar.ingestion.batch.FileIngestionJob input/ output/${NC}"

echo -e "\n${BLUE}📚 For complete setup including prerequisites:${NC}"
echo -e "   ${YELLOW}./setup-dev-env.sh${NC}"

echo -e "\n${BLUE}🛑 To stop services:${NC}"
echo -e "   ${YELLOW}cd spark-apps/docker && $DOCKER_COMPOSE down${NC}\n"