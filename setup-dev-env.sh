#!/bin/bash
###############################################################################
# SmartStar Development Environment - Complete Setup Script
# 
# This script sets up the complete development environment including:
# - Prerequisites (Java, Scala, SBT, Python, Docker)
# - Docker services (Kafka, MinIO, PostgreSQL, Mosquitto, etc.)
# - Kafka topics, S3 buckets, and connectors
#
# Usage:
#   ./setup-dev-env.sh              # Interactive menu
#   ./setup-dev-env.sh start        # Start Docker services only
#   ./setup-dev-env.sh setup        # Full setup (install deps + start)
#   ./setup-dev-env.sh stop         # Stop all services
#   ./setup-dev-env.sh status       # Show service status
#   ./setup-dev-env.sh logs         # Tail service logs
#   ./setup-dev-env.sh clean        # Stop and remove all data
#   ./setup-dev-env.sh test <func>  # Test individual function
#   ./setup-dev-env.sh health       # Check environment health
#
###############################################################################

set -e

# ==============================================================================
# Configuration
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/infrastructure/docker"
COMPOSE_FILE="$DOCKER_DIR/docker-compose.yml"
PROJECT_NAME="smartstar"

# Version configurations
JAVA_VERSION="${JAVA_VERSION:-21}"
SCALA_VERSION="${SCALA_VERSION:-2.13.12}"
CONNECTOR_VERSION="${CONNECTOR_VERSION:-10.0.0}"

# GitHub and external service URLs
GITHUB_BASE_URL="${GITHUB_BASE_URL:-https://github.com}"
STREAM_REACTOR_BASE_URL="${STREAM_REACTOR_BASE_URL:-${GITHUB_BASE_URL}/lensesio/stream-reactor/releases/download}"
COURSIER_DOWNLOAD_URL="${COURSIER_DOWNLOAD_URL:-${GITHUB_BASE_URL}/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz}"
MINIO_CLIENT_URL="${MINIO_CLIENT_URL:-https://dl.min.io/client/mc/release/linux-amd64/mc}"

# Service endpoints
KAFKA_BOOTSTRAP="${KAFKA_BOOTSTRAP:-localhost:9094}"
KAFKA_INTERNAL="${KAFKA_INTERNAL:-localhost:9092}"
KAFKA_CONNECT_URL="${KAFKA_CONNECT_URL:-http://localhost:8083}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost:9000}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-minioadmin}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-minioadmin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ==============================================================================
# Logging
# ==============================================================================
log()     { echo -e "${BLUE}▸${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1"; }
header()  { echo -e "\n${BOLD}${CYAN}$1${NC}"; }

# ==============================================================================
# Docker Compose command detection
# ==============================================================================
get_compose_cmd() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        error "Docker Compose not found. Please install Docker Compose."
        exit 1
    fi
}

# ==============================================================================
# OS Detection
# ==============================================================================
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -q Microsoft /proc/version 2>/dev/null; then
            echo "wsl"
        elif command -v apt-get &> /dev/null; then
            echo "ubuntu"
        elif command -v yum &> /dev/null; then
            echo "rhel"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# ==============================================================================
# Pre-flight checks
# ==============================================================================
preflight_check() {
    header "Pre-flight checks"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        echo "  → https://docs.docker.com/get-docker/"
        exit 1
    fi
    success "Docker is installed"
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    success "Docker daemon is running"
    
    # Check compose file
    if [ ! -f "$COMPOSE_FILE" ]; then
        error "docker-compose.yml not found at $COMPOSE_FILE"
        exit 1
    fi
    success "Compose file found"
}

# ==============================================================================
# Install Java
# ==============================================================================
install_java() {
    header "Installing Java $JAVA_VERSION"
    
    if java -version 2>&1 | grep -qE "openjdk version \"$JAVA_VERSION|version \"$JAVA_VERSION"; then
        success "Java $JAVA_VERSION is already installed"
            return 0
        fi
        
    local os=$(detect_os)
        case $os in
        "ubuntu"|"wsl")
            sudo apt update
            sudo apt install -y openjdk-${JAVA_VERSION}-jdk
                ;;
            "macos")
            if command -v brew &> /dev/null; then
                    brew install openjdk@$JAVA_VERSION
                else
                error "Homebrew not found. Please install Java manually."
                    return 1
                fi
                ;;
            *)
            error "Unsupported OS for automatic Java installation"
                return 1
                ;;
        esac
        
    # Set JAVA_HOME
    if [ -d "/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64" ]; then
        echo "export JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64" >> ~/.bashrc
        export JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64
    fi
    
    success "Java $JAVA_VERSION installed"
}

# ==============================================================================
# Install Scala
# ==============================================================================
install_scala() {
    header "Installing Scala $SCALA_VERSION"
    
    if scala -version 2>&1 | grep -q "2.13"; then
        success "Scala 2.13 is already installed"
            return 0
    fi
    
    # Install coursier
    if ! command -v cs &> /dev/null; then
        log "Installing Coursier..."
        curl -fL "$COURSIER_DOWNLOAD_URL" | gzip -d > /tmp/cs
        chmod +x /tmp/cs
        sudo mv /tmp/cs /usr/local/bin/cs
    fi
    
    # Install Scala via coursier
    cs install scala:$SCALA_VERSION --force
    
    # Add to PATH
    if ! grep -q "coursier/bin" ~/.bashrc; then
        echo 'export PATH="$PATH:$HOME/.local/share/coursier/bin"' >> ~/.bashrc
    fi
    export PATH="$PATH:$HOME/.local/share/coursier/bin"
    
    success "Scala $SCALA_VERSION installed"
}

# ==============================================================================
# Install SBT
# ==============================================================================
install_sbt() {
    header "Installing SBT"
    
    if command -v sbt &> /dev/null; then
        success "SBT is already installed"
        return 0
    fi
        
    local os=$(detect_os)
        case $os in
        "ubuntu"|"wsl")
            sudo apt update
            sudo apt install -y apt-transport-https curl gnupg
            echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list
            echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | sudo tee /etc/apt/sources.list.d/sbt_old.list
            curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | \
                gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/sbt.gpg > /dev/null
            sudo apt update
            sudo apt install -y sbt
                ;;
            "macos")
            if command -v brew &> /dev/null; then
                    brew install sbt
                else
                error "Homebrew not found. Please install SBT manually."
                    return 1
                fi
                ;;
        *)
            error "Unsupported OS for automatic SBT installation"
                return 1
                ;;
        esac
        
    success "SBT installed"
}

# ==============================================================================
# Install Python
# ==============================================================================
install_python() {
    header "Installing Python 3"
    
    if command -v python3 &> /dev/null; then
        success "Python 3 is already installed: $(python3 --version)"
        return 0
    fi
    
    local os=$(detect_os)
            case $os in
        "ubuntu"|"wsl")
            sudo apt install -y python3 python3-pip python3-venv python3-dev
                    ;;
                "macos")
            if command -v brew &> /dev/null; then
                brew install python
            fi
                ;;
        esac
        
    # Create python symlink
    if ! command -v python &> /dev/null; then
        sudo ln -sf /usr/bin/python3 /usr/bin/python 2>/dev/null || true
    fi
    
    # Install common packages
    pip3 install --user paho-mqtt faker requests 2>/dev/null || true
    
    success "Python 3 installed"
}

# ==============================================================================
# Install Docker
# ==============================================================================
install_docker() {
    header "Installing Docker"
    
    local os=$(detect_os)
    
    # WSL special handling
    if [ "$os" = "wsl" ]; then
        if command -v docker &> /dev/null && docker info &> /dev/null; then
            success "Docker is accessible via WSL integration"
            return 0
        else
            warn "Docker Desktop WSL integration not configured"
            log "Please enable WSL integration in Docker Desktop settings:"
            log "1. Open Docker Desktop on Windows"
            log "2. Go to Settings → Resources → WSL Integration"
            log "3. Enable integration with your WSL distro"
            log "4. Apply & Restart Docker Desktop"
        return 1
    fi
    fi
    
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        success "Docker and Docker Compose are already installed"
        return 0
    fi
    
    case $os in
        "ubuntu")
            # Remove old versions
            sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            
            # Install dependencies
            sudo apt update
            sudo apt install -y ca-certificates curl gnupg lsb-release
            
            # Add Docker GPG key
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Set up repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            
            # Add user to docker group
            sudo usermod -aG docker $USER
            
            # Start Docker
            sudo systemctl start docker
            sudo systemctl enable docker
            
            success "Docker installed. Please log out and back in for group changes."
            ;;
        "macos")
            error "Please install Docker Desktop for Mac from https://docker.com"
            return 1
            ;;
        *)
            error "Unsupported OS for automatic Docker installation"
            return 1
            ;;
    esac
}

# ==============================================================================
# Install Utilities
# ==============================================================================
install_utilities() {
    header "Installing utilities"
    
    local os=$(detect_os)
    case $os in
        "ubuntu"|"wsl")
            sudo apt install -y jq curl wget git tree unzip
            ;;
        "macos")
            brew install jq curl wget git tree unzip 2>/dev/null || true
            ;;
    esac
    
    # Install MinIO client if not present
    if ! command -v mc &> /dev/null; then
        log "Installing MinIO client (mc)..."
        curl -sSL "$MINIO_CLIENT_URL" -o /tmp/mc
        chmod +x /tmp/mc
        sudo mv /tmp/mc /usr/local/bin/mc
        success "MinIO client installed"
    fi
    
    success "Utilities installed"
}

# ==============================================================================
# Download MQTT Kafka Connector
# ==============================================================================
download_mqtt_connector() {
    header "Downloading Kafka Connect MQTT Connector"
    
    local download_url="${STREAM_REACTOR_BASE_URL}/${CONNECTOR_VERSION}/kafka-connect-mqtt-${CONNECTOR_VERSION}.zip"
    local plugins_dir="$DOCKER_DIR/kafka-connect/plugins"
    local jar_name="kafka-connect-mqtt-assembly-${CONNECTOR_VERSION}.jar"
    
    # Check if already exists
    if [ -f "$plugins_dir/$jar_name" ]; then
        success "MQTT connector already installed"
        return 0
    fi
    
    mkdir -p "$plugins_dir"
    
    log "Downloading connector v${CONNECTOR_VERSION}..."
    local temp_dir=$(mktemp -d)
    
    if curl -L -o "$temp_dir/connector.zip" "$download_url"; then
        cd "$temp_dir"
        unzip -q connector.zip
        
        # Find and copy assembly JAR
        local assembly_jar=$(find . -name "*assembly*.jar" -type f | head -n 1)
        if [ -n "$assembly_jar" ]; then
            cp "$assembly_jar" "$plugins_dir/$jar_name"
            success "MQTT connector installed to $plugins_dir"
        else
            warn "Assembly JAR not found in downloaded package"
        fi
        
        cd - > /dev/null
    else
        error "Failed to download connector"
    fi
    
    rm -rf "$temp_dir"
}

# ==============================================================================
# Create Kafka topics
# ==============================================================================
create_kafka_topics() {
    header "Creating Kafka topics"
    
    local topics=(
        "sensors.temperature"
        "sensors.motion"
        "sensors.air_quality"
        "sensors.smart_meter"
        "sensors.weather"
        "sensors.vehicle"
        "events.user"
        "events.system"
    )
    
        for topic in "${topics[@]}"; do
        log "Creating topic: $topic"
        docker exec smartstar-kafka /opt/kafka/bin/kafka-topics.sh \
                --bootstrap-server localhost:9092 \
                --create \
                --topic "$topic" \
                --partitions 3 \
                --replication-factor 1 \
            --if-not-exists 2>/dev/null || true
    done
    
    success "Kafka topics created"
    
    # List topics
    log "Listing Kafka topics:"
    docker exec smartstar-kafka /opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server localhost:9092 --list 2>/dev/null || true
}

# ==============================================================================
# Create MinIO buckets
# ==============================================================================
create_minio_buckets() {
    header "Creating MinIO buckets"
    
    # Wait for MinIO
    local max_attempts=30
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$MINIO_ENDPOINT/minio/health/live" &>/dev/null; then
            break
        fi
        sleep 1
        ((attempt++))
    done
    
    # Create buckets
    docker exec smartstar-minio sh -c "
        mc alias set local http://localhost:9000 $MINIO_ACCESS_KEY $MINIO_SECRET_KEY 2>/dev/null
        mc mb --ignore-existing local/smartstar 2>/dev/null
        mc mb --ignore-existing local/bronze 2>/dev/null
        mc mb --ignore-existing local/silver 2>/dev/null
        mc mb --ignore-existing local/gold 2>/dev/null
        mc mb --ignore-existing local/checkpoints 2>/dev/null
    " 2>/dev/null || true
    
    success "MinIO buckets created"
}

# ==============================================================================
# Initialize MQTT Connector
# ==============================================================================
init_mqtt_connector() {
    header "Initializing MQTT Kafka Connector"
    
    local connector_name="mqtt-source-sensors"
    
    # Wait for Kafka Connect
    log "Waiting for Kafka Connect..."
    local max_attempts=60
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$KAFKA_CONNECT_URL/" &>/dev/null; then
            success "Kafka Connect is ready"
            break
        fi
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        error "Kafka Connect not ready after timeout"
        return 1
    fi
    
    # Delete existing connector
    curl -sf -X DELETE "$KAFKA_CONNECT_URL/connectors/$connector_name" &>/dev/null || true
    sleep 2
    
    # Create connector
    log "Creating MQTT source connector..."
    
    # Build JSON payload (escaping backticks for KCQL)
    local payload
    payload=$(cat <<EOF
{
    "name": "$connector_name",
    "config": {
        "connector.class": "io.lenses.streamreactor.connect.mqtt.source.MqttSourceConnector",
        "tasks.max": "1",
        "connect.mqtt.hosts": "tcp://smartstar-mosquitto:1883",
        "connect.mqtt.service.quality": "1",
        "connect.mqtt.client.id": "kafka-connect-mqtt-sensors",
        "connect.mqtt.connection.timeout": "30000",
        "connect.mqtt.connection.keep.alive": "60000",
        "connect.mqtt.connection.clean.session": "true",
        "connect.mqtt.kcql": "INSERT INTO sensors.temperature SELECT * FROM sensors/temperature/+ WITHKEY(device_id, timestamp); INSERT INTO sensors.air_quality SELECT * FROM sensors/air_quality/+ WITHKEY(device_id, timestamp); INSERT INTO sensors.motion SELECT * FROM sensors/motion/+ WITHKEY(device_id, timestamp);",
        "key.converter": "org.apache.kafka.connect.storage.StringConverter",
        "value.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",
        "key.converter.schemas.enable": "false",
        "value.converter.schemas.enable": "false"
    }
}
EOF
)
    
    curl -sf -X POST -H "Content-Type: application/json" \
        -d "$payload" "$KAFKA_CONNECT_URL/connectors" &>/dev/null && \
        success "MQTT connector created" || warn "Failed to create connector (plugin may be missing)"
    
    # Show status
    sleep 3
    log "Connector status:"
    curl -sf "$KAFKA_CONNECT_URL/connectors/$connector_name/status" 2>/dev/null | jq '.' 2>/dev/null || \
        curl -sf "$KAFKA_CONNECT_URL/connectors" 2>/dev/null || true
}

# ==============================================================================
# Environment Health Check
# ==============================================================================
check_health() {
    header "Environment Health Check"
    
    local errors=0
    
    # Check Java
    if command -v java &> /dev/null; then
        success "Java: $(java -version 2>&1 | head -n1)"
    else
        error "Java not found"
        ((errors++))
    fi
    
    # Check Scala
    if command -v scala &> /dev/null; then
        success "Scala: $(scala -version 2>&1 | head -n1)"
    else
        warn "Scala not found (optional)"
    fi
    
    # Check SBT
    if command -v sbt &> /dev/null; then
        success "SBT: installed"
    else
        warn "SBT not found (optional)"
    fi
    
    # Check Python
    if command -v python3 &> /dev/null; then
        success "Python: $(python3 --version)"
    else
        warn "Python 3 not found"
    fi
    
    # Check Docker
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        success "Docker: $(docker --version)"
    else
        error "Docker not accessible"
        ((errors++))
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        success "Docker Compose: $(docker compose version --short)"
    else
        error "Docker Compose not found"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        success "Health check passed!"
        return 0
    else
        error "Health check failed with $errors errors"
        return 1
    fi
}

# ==============================================================================
# Wait for services
# ==============================================================================
wait_for_services() {
    header "Waiting for services to be healthy"
    
    local services=("smartstar-kafka" "smartstar-postgres" "smartstar-minio" "smartstar-mosquitto")
    local max_wait=120
    
    for svc in "${services[@]}"; do
        log "Waiting for $svc..."
        local elapsed=0
        while [ $elapsed -lt $max_wait ]; do
            if docker inspect --format='{{.State.Health.Status}}' "$svc" 2>/dev/null | grep -q "healthy"; then
                success "$svc is healthy"
                break
            elif docker inspect --format='{{.State.Status}}' "$svc" 2>/dev/null | grep -q "running"; then
                success "$svc is running"
                break
            fi
            sleep 2
            ((elapsed+=2))
        done
    done
}

# ==============================================================================
# Start services
# ==============================================================================
start_services() {
    header "Starting SmartStar Docker Services"
    
    preflight_check
    
    # Download MQTT connector before starting (so Kafka Connect loads it on startup)
    download_mqtt_connector
    
    local compose_cmd=$(get_compose_cmd)
    
    log "Pulling latest images..."
    $compose_cmd -f "$COMPOSE_FILE" -p "$PROJECT_NAME" pull --quiet 2>/dev/null || true
    
    log "Starting services..."
    $compose_cmd -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d
    
    wait_for_services
    create_kafka_topics
    create_minio_buckets
    
    show_status
    show_urls
}

# ==============================================================================
# Stop services
# ==============================================================================
stop_services() {
    header "Stopping SmartStar services"
    local compose_cmd=$(get_compose_cmd)
    $compose_cmd -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down
    success "All services stopped"
}

# ==============================================================================
# Show status
# ==============================================================================
show_status() {
    header "Service Status"
    docker ps --filter "name=smartstar" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
    $(get_compose_cmd) -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps
}

# ==============================================================================
# Show logs
# ==============================================================================
show_logs() {
    $(get_compose_cmd) -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f
}

# ==============================================================================
# Clean everything
# ==============================================================================
clean_all() {
    header "Cleaning SmartStar environment"
    warn "This will remove all containers, volumes, and data!"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local compose_cmd=$(get_compose_cmd)
        $compose_cmd -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down -v --remove-orphans
        
        # Clean up any leftover processes on ports
        log "Checking for processes on service ports..."
        for port in 1883 5432 8080 8083 9000 9001 9092 9094; do
            local pid=$(sudo lsof -ti ":$port" 2>/dev/null || true)
            if [ -n "$pid" ]; then
                log "Killing process $pid on port $port"
                sudo kill -9 "$pid" 2>/dev/null || true
            fi
        done
        
        success "Environment cleaned"
    else
        log "Cancelled"
    fi
}

# ==============================================================================
# Full Setup (install deps + start)
# ==============================================================================
full_setup() {
    header "Running Full Setup"
    
    local os=$(detect_os)
    log "Detected OS: $os"
    
    # Update system (Ubuntu/WSL only)
    if [ "$os" = "ubuntu" ] || [ "$os" = "wsl" ]; then
        log "Updating system packages..."
        sudo apt update && sudo apt upgrade -y
    fi
    
    # Install prerequisites
    install_utilities
    install_java
    install_scala  
    install_sbt
    install_python
    install_docker
    
    # Source bashrc for new PATH entries
    source ~/.bashrc 2>/dev/null || true
    
    # Health check
    if ! check_health; then
        warn "Some components missing, but continuing..."
    fi
    
    # Start Docker services
    start_services
    
    success "Full setup completed!"
}

# ==============================================================================
# Complete Setup (full + connectors)
# ==============================================================================
complete_setup() {
    full_setup
    
    header "Initializing Connectors"
    
    # Wait for Kafka Connect to be fully ready with plugins loaded
    log "Waiting for Kafka Connect to load plugins..."
    sleep 15
    
    # Initialize MQTT connector
    init_mqtt_connector
    
    success "Complete setup finished! Environment is ready."
}

# ==============================================================================
# Show URLs
# ==============================================================================
show_urls() {
        echo ""
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${GREEN}  🚀 SmartStar Development Environment Ready!${NC}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    echo -e "${BOLD}Service URLs:${NC}"
    echo -e "  ${CYAN}Kafka UI${NC}        → ${GREEN}http://localhost:8080${NC}"
    echo -e "  ${CYAN}Schema Registry${NC} → ${GREEN}http://localhost:8081${NC}"
    echo -e "  ${CYAN}MinIO Console${NC}   → ${GREEN}http://localhost:9001${NC}  (minioadmin / minioadmin)"
    echo -e "  ${CYAN}Kafka Connect${NC}   → ${GREEN}http://localhost:8083${NC}"
        echo ""
    echo -e "${BOLD}Connection Endpoints:${NC}"
    echo -e "  ${CYAN}Kafka${NC}           → ${GREEN}localhost:9094${NC}"
    echo -e "  ${CYAN}PostgreSQL${NC}      → ${GREEN}localhost:5432${NC}  (smartstar / smartstar)"
    echo -e "  ${CYAN}MQTT${NC}            → ${GREEN}localhost:1883${NC}"
    echo -e "  ${CYAN}MinIO S3${NC}        → ${GREEN}localhost:9000${NC}"
        echo ""
    echo -e "${BOLD}Quick Commands:${NC}"
    echo -e "  ${YELLOW}./setup-dev-env.sh status${NC}  - Check service status"
    echo -e "  ${YELLOW}./setup-dev-env.sh logs${NC}    - View logs"
    echo -e "  ${YELLOW}./setup-dev-env.sh stop${NC}    - Stop services"
    echo -e "  ${YELLOW}./setup-dev-env.sh clean${NC}   - Remove everything"
    echo ""
    echo -e "${BOLD}Generate Test Data:${NC}"
    echo -e "  ${YELLOW}python3 spark-apps/dev-tools/sensor-data.generator.py --broker localhost --port 1883 --duration 60${NC}"
    echo ""
}

# ==============================================================================
# Test individual function
# ==============================================================================
test_function() {
    local func_name="${1:-}"
    
    if [ -z "$func_name" ]; then
        echo ""
        log "Available functions to test:"
        echo "  1) install_java"
        echo "  2) install_scala"
        echo "  3) install_sbt"
        echo "  4) install_python"
        echo "  5) install_docker"
        echo "  6) install_utilities"
        echo "  7) create_kafka_topics"
        echo "  8) create_minio_buckets"
        echo "  9) init_mqtt_connector"
        echo " 10) download_mqtt_connector"
        echo " 11) check_health"
        echo ""
        read -p "Select function (1-11) or type name: " choice
        
        case $choice in
            1|install_java) install_java ;;
            2|install_scala) install_scala ;;
            3|install_sbt) install_sbt ;;
            4|install_python) install_python ;;
            5|install_docker) install_docker ;;
            6|install_utilities) install_utilities ;;
            7|create_kafka_topics) create_kafka_topics ;;
            8|create_minio_buckets) create_minio_buckets ;;
            9|init_mqtt_connector) init_mqtt_connector ;;
            10|download_mqtt_connector) download_mqtt_connector ;;
            11|check_health) check_health ;;
            *) error "Unknown function: $choice" ;;
        esac
    else
        # Direct function call
        if declare -f "$func_name" > /dev/null; then
            $func_name
        else
            error "Unknown function: $func_name"
            exit 1
        fi
    fi
}

# ==============================================================================
# Interactive Menu
# ==============================================================================
show_menu() {
    echo ""
    echo -e "${BOLD}${CYAN}SmartStar Development Environment${NC}"
    echo ""
    echo "  1) start     - Start Docker services only"
    echo "  2) setup     - Full setup (install deps + start services)"
    echo "  3) complete  - Complete setup (full + connectors)"
    echo "  4) stop      - Stop all services"
    echo "  5) status    - Show service status"
    echo "  6) health    - Check environment health"
    echo "  7) clean     - Remove everything"
    echo "  8) test      - Test individual function"
    echo "  9) exit      - Exit"
    echo ""
    read -p "Select option (1-9): " -n 1 -r
    echo ""
    
    case $REPLY in
        1) start_services ;;
        2) full_setup ;;
        3) complete_setup ;;
        4) stop_services ;;
        5) show_status ;;
        6) check_health ;;
        7) clean_all ;;
        8) test_function ;;
        9) exit 0 ;;
        *) error "Invalid option" ;;
    esac
}

# ==============================================================================
# Banner
# ==============================================================================
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
   _____ __  __          _____ _______  _____ _______       _____  
  / ____|  \/  |   /\   |  __ \__   __|/ ____|__   __|/\   |  __ \ 
 | (___ | \  / |  /  \  | |__) | | |  | (___    | |  /  \  | |__) |
  \___ \| |\/| | / /\ \ |  _  /  | |   \___ \   | | / /\ \ |  _  / 
  ____) | |  | |/ ____ \| | \ \  | |   ____) |  | |/ ____ \| | \ \ 
 |_____/|_|  |_/_/    \_\_|  \_\ |_|  |_____/   |_/_/    \_\_|  \_\
                                                                    
EOF
    echo -e "${NC}"
    echo -e "${BOLD}IoT Data Platform - Development Environment${NC}"
    echo ""
}

# ==============================================================================
# Main
# ==============================================================================
main() {
    cd "$SCRIPT_DIR"
    
    case "${1:-}" in
        start|up)
            show_banner
            start_services
            ;;
        stop|down)
            stop_services
            ;;
        restart)
            stop_services
            start_services
            ;;
        status|ps)
            show_status
            ;;
        logs)
            show_logs
            ;;
        clean|destroy)
            clean_all
            ;;
        setup)
            show_banner
            full_setup
            ;;
        complete|all)
            show_banner
            complete_setup
            ;;
        health|check)
            check_health
            ;;
        test)
            test_function "${2:-}"
            ;;
        urls)
            show_urls
            ;;
        -h|--help|help)
            show_banner
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  start      Start Docker services only (quick)"
            echo "  setup      Full setup (install deps + start)"
            echo "  complete   Complete setup (full + connectors)"
            echo "  stop       Stop all services"
            echo "  restart    Restart all services"
            echo "  status     Show service status"
            echo "  logs       Tail service logs"
            echo "  clean      Stop and remove all data"
            echo "  health     Check environment health"
            echo "  test       Test individual function"
            echo "  urls       Show service URLs"
            echo "  help       Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                    # Interactive menu"
            echo "  $0 start              # Quick start services"
            echo "  $0 setup              # Full setup with deps"
            echo "  $0 test install_java  # Test single function"
            echo ""
            ;;
        "")
            # No argument - show interactive menu
            show_banner
            show_menu
            ;;
        *)
            error "Unknown command: $1"
            echo "Run '$0 --help' for usage"
            exit 1
        ;;
esac
}

main "$@"
