#!/bin/bash

# Local Development Stack Setup Script for Ubuntu 22.04+
# This script automates the installation and setup of your development environment

set -e  # Exit on any error

# Get the script's directory and navigate to docker directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(realpath "$SCRIPT_DIR/../docker")"

# Change to the docker directory where docker-compose files are located
cd "$DOCKER_DIR" || {
    log_error "Cannot find docker directory at $DOCKER_DIR"
    log_error "Please ensure the directory structure is: spark-apps/dev-tools/ and spark-apps/docker/"
    exit 1
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

MINIO_ENDPOINT="http://localhost:9000"
MINIO_ACCESS_KEY="minioadmin"
MINIO_SECRET_KEY="minioadmin"
BUCKET_NAME="smartstar"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verify we're in the right place
verify_working_directory() {
    log_info "Script location: $SCRIPT_DIR"
    log_info "Working directory: $(pwd)"
    
    if [ ! -f "docker-compose-dev.yml" ] && [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose files not found in $(pwd)"
        log_error "Expected files: docker-compose-dev.yml or docker-compose.yml"
        exit 1
    fi
    
    log_success "Working in correct directory: $(pwd)"
}

# Check Ubuntu version
check_ubuntu_version() {
    log_info "Checking Ubuntu version..."
    
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "This script only supports Ubuntu 22.04+"
        exit 1
    fi
    
    VERSION=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2)
    MAJOR_VERSION=$(echo $VERSION | cut -d '.' -f 1)
    MINOR_VERSION=$(echo $VERSION | cut -d '.' -f 2)
    
    if [ "$MAJOR_VERSION" -lt 22 ] || ([ "$MAJOR_VERSION" -eq 20 ] && [ "$MINOR_VERSION" -lt 4 ]); then
        log_error "Ubuntu $VERSION detected. This script requires Ubuntu 22.04+"
        exit 1
    fi
    
    log_success "Ubuntu $VERSION detected - supported version"
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    log_success "System updated"
}

# Cleanup function - stops containers and removes all created directories
cleanup_environment() {
    log_info "Starting environment cleanup..."
    
    # Stop and remove all Docker containers and networks
    log_info "Stopping and removing Docker containers..."
    if [ -f "docker-compose-dev.yml" ] || [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
        # Try different permission methods for docker-compose down
        if docker compose -f docker-compose-dev.yml down --remove-orphans --volumes 2>/dev/null; then
            log_success "Docker services stopped with docker compose"
        elif sg docker -c "docker compose -f docker-compose-dev.yml down --remove-orphans --volumes" 2>/dev/null; then
            log_success "Docker services stopped with sg docker"
        elif sudo docker compose -f docker-compose-dev.yml down --remove-orphans --volumes 2>/dev/null; then
            log_success "Docker services stopped with sudo"
        else
            log_warning "Could not stop services with docker-compose, trying manual cleanup..."
        fi
    fi
    
    # Stop any remaining containers that might be running
    log_info "Stopping any remaining containers..."
    RUNNING_CONTAINERS=$(docker ps -q 2>/dev/null || sg docker -c "docker ps -q" 2>/dev/null || sudo docker ps -q 2>/dev/null)
    if [ -n "$RUNNING_CONTAINERS" ]; then
        if docker stop $RUNNING_CONTAINERS 2>/dev/null; then
            log_info "Stopped running containers"
        elif sg docker -c "docker stop $RUNNING_CONTAINERS" 2>/dev/null; then
            log_info "Stopped running containers with sg docker"
        elif sudo docker stop $RUNNING_CONTAINERS 2>/dev/null; then
            log_info "Stopped running containers with sudo"
        fi
    fi
    
    # Remove all containers (including stopped ones)
    log_info "Removing all containers..."
    if docker container prune -f 2>/dev/null; then
        log_info "Containers pruned"
    elif sg docker -c "docker container prune -f" 2>/dev/null; then
        log_info "Containers pruned with sg docker"
    elif sudo docker container prune -f 2>/dev/null; then
        log_info "Containers pruned with sudo"
    fi
    
    # Remove Docker volumes
    log_info "Removing Docker volumes..."
    if docker volume prune -f 2>/dev/null; then
        log_info "Volumes pruned"
    elif sg docker -c "docker volume prune -f" 2>/dev/null; then
        log_info "Volumes pruned with sg docker"
    elif sudo docker volume prune -f 2>/dev/null; then
        log_info "Volumes pruned with sudo"
    fi
    
    # Remove Docker networks
    log_info "Removing Docker networks..."
    if docker network prune -f 2>/dev/null; then
        log_info "Networks pruned"
    elif sg docker -c "docker network prune -f" 2>/dev/null; then
        log_info "Networks pruned with sg docker"
    elif sudo docker network prune -f 2>/dev/null; then
        log_info "Networks pruned with sudo"
    fi
    
    # Remove service directories and their contents
    log_info "Removing service directories and data..."
    
    # Mosquitto directories
    if [ -d "./mosquitto" ]; then
        log_info "Removing Mosquitto directories..."
        sudo rm -rf ./mosquitto/config
        sudo rm -rf ./mosquitto/data
        sudo rm -rf ./mosquitto/logs
        log_success "Mosquitto directories removed"
    fi
    
    # Kafka directories
    if [ -d "./kafka" ]; then
        log_info "Removing Kafka directories..."
        sudo rm -rf ./kafka/data
        sudo rm -rf ./kafka/logs
        sudo rm -rf ./kafka/metadata
        sudo rm -rf ./kafka/plugins
        sudo rm -f ./kafka/connect-distributed.properties
        log_success "Kafka directories removed"
    fi
    
    # MinIO directories
    if [ -d "./minio" ]; then
        log_info "Removing MinIO directories..."
        sudo rm -rf ./minio/data
        log_success "MinIO directories removed"
    fi
    
    # PostgreSQL directories
    if [ -d "./postgres" ]; then
        log_info "Removing PostgreSQL directories..."
        sudo rm -rf ./postgres/data
        log_success "PostgreSQL directories removed"
    fi
    
    # Kill any processes that might still be using the ports
    log_info "Checking for processes using service ports..."
    
    # Common ports used by services
    PORTS="1883 5432 8080 8083 9000 9001 9092 9093 9094"
    
    for port in $PORTS; do
        PID=$(sudo lsof -ti :$port 2>/dev/null)
        if [ -n "$PID" ]; then
            log_info "Killing process $PID using port $port"
            sudo kill -9 $PID 2>/dev/null || true
        fi
    done
    
    # Clean up any remaining processes by name
    log_info "Cleaning up service processes..."
    sudo pkill -f "mosquitto" 2>/dev/null || true
    sudo pkill -f "kafka" 2>/dev/null || true
    sudo pkill -f "minio" 2>/dev/null || true
    sudo pkill -f "postgres" 2>/dev/null || true
    
    # Show remaining directory structure
    log_info "Remaining directory structure:"
    ls -la . | grep -E "mosquitto|kafka|minio|postgres" || log_info "All service directories removed"
    
    log_success "Environment cleanup completed!"
    log_info "You can now run the setup script again with a clean environment"
}

# Interactive cleanup function
interactive_cleanup() {
    echo
    log_warning "This will:"
    log_warning "   • Stop and remove ALL Docker containers"
    log_warning "   • Remove ALL Docker volumes and networks"
    log_warning "   • Delete ALL service data directories"
    log_warning "   • Kill processes using service ports"
    echo
    read -p "Are you sure you want to proceed with cleanup? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_environment
    else
        log_info "Cleanup cancelled"
        exit 0
    fi
}

# Install Java 21
install_java() {
    log_info "Installing Java 21..."
    
    if java -version 2>&1 | grep -q "openjdk version \"21"; then
        log_success "Java 21 is already installed"
        return
    fi
    
    sudo apt install -y openjdk-21-jdk
    
    # Set JAVA_HOME
    echo 'export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64' >> ~/.bashrc
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
    
    log_success "Java 21 installed"
}

# Install Scala 2.13
install_scala() {
    log_info "Installing Scala 2.13..."
    
    if scala -version 2>&1 | grep -q "2.13"; then
        log_success "Scala 2.13 is already installed"
        return
    fi
    
    # Install coursier
    curl -fL https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz | gzip -d > cs
    chmod +x cs
    sudo mv cs /usr/local/bin/
    
    # Install Scala 2.13
    cs install scala:2.13.12 --force
    
    # Add to PATH
    echo 'export PATH="$PATH:~/.local/share/coursier/bin"' >> ~/.bashrc
    export PATH="$PATH:~/.local/share/coursier/bin"
    
    log_success "Scala 2.13 installed"
}

# Install SBT
install_sbt() {
    log_info "Installing SBT (latest version)..."
    
    if command -v sbt > /dev/null 2>&1; then
        log_success "SBT is already installed"
        return
    fi
    
    echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list
    echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | sudo tee /etc/apt/sources.list.d/sbt_old.list
    curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/sbt.gpg > /dev/null
    sudo apt update
    sudo apt install -y sbt
    
    log_success "SBT installed"
}

# Install Python 3
install_python() {
    log_info "Installing Python 3 (latest)..."
    
    sudo apt install -y python3 python3-pip python3-venv python3-dev
    
    # Create python symlink if it doesn't exist
    if ! command -v python > /dev/null 2>&1; then
        sudo ln -sf /usr/bin/python3 /usr/bin/python
    fi
    
    log_success "Python 3 installed"
}

# Create required directories for Docker services
create_service_directories() {
    log_info "Creating required directories for Docker services..."
    
    # Mosquitto MQTT directories
    log_info "Creating Mosquitto directories..."
    mkdir -p ./mosquitto/config
    mkdir -p ./mosquitto/data
    mkdir -p ./mosquitto/logs
    
    # Kafka directories
    log_info "Creating Kafka directories..."
    mkdir -p ./kafka/data
    mkdir -p ./kafka/logs
    mkdir -p ./kafka/metadata
    mkdir -p ./kafka/plugins

    # MinIO directories
    log_info "Creating MinIO directories..."
    mkdir -p ./minio/data
    
    # PostgreSQL directories
    log_info "Creating PostgreSQL directories..."
    mkdir -p ./postgres/data
    
    # Set appropriate permissions for directories that need them
    log_info "Setting directory permissions..."
    
    # Mosquitto needs specific permissions
    sudo chmod 755 ./mosquitto/data
    sudo chmod 755 ./mosquitto/logs

    # Kafka directories - ensure they're writable
    sudo chmod 755 ./kafka/data
    sudo chmod 755 ./kafka/logs
    sudo chmod 755 ./kafka/metadata
    sudo chmod 755 ./kafka/plugins

    # MinIO data directory
    sudo chmod 755 ./minio/data
    
    # PostgreSQL data directory
    sudo chmod 755 ./postgres/data

    log_success "All required directories created successfully"

    log_info "Setting up Mosquitto configuration..."
    # Create basic Mosquitto config if it doesn't exist
    if [ ! -f "./mosquitto/config/mosquitto.conf" ]; then
        log_info "Creating basic Mosquitto configuration..."
        cat > ./mosquitto/config/mosquitto.conf <<-EOF
listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/logs/mosquitto.log
log_type all
EOF
        log_success "Basic Mosquitto configuration created"
    fi

    log_info "Setting up Kafka Connect plugins..."
    # Look for the JAR file in multiple locations
    JAR_LOCATIONS=(
        "../lib/kafka-connect-mqtt-assembly-10.0.0.jar"
        "../libs/kafka-connect-mqtt-assembly-10.0.0.jar" 
        "../../lib/kafka-connect-mqtt-assembly-10.0.0.jar"
        "./kafka-connect-mqtt-assembly-10.0.0.jar"
    )
    
    JAR_FOUND=false
    for jar_path in "${JAR_LOCATIONS[@]}"; do
        if [ -f "$jar_path" ]; then
            cp "$jar_path" ./kafka/plugins/ 2>/dev/null && {
                log_success "Kafka Connect MQTT JAR copied from $jar_path"
                JAR_FOUND=true
                break
            }
        fi
    done
    
    if [ "$JAR_FOUND" = false ]; then
        log_warning "Kafka Connect MQTT JAR not found. Please manually copy it to ./kafka/plugins/"
        log_info "Expected file: kafka-connect-mqtt-assembly-10.0.0.jar"
    fi

    # Create basic Kafka Connect configuration if it doesn't exist
    if [ ! -f "./kafka/connect-distributed.properties" ]; then
        log_info "Creating basic Kafka Connect configuration..."
        cat > ./kafka/connect-distributed.properties << EOF
# Kafka Connect Distributed Configuration
bootstrap.servers=smartstar-kafka-broker:9092
group.id=external-connect-cluster

# Topic names for Connect internal topics
config.storage.topic=_connect-configs
offset.storage.topic=_connect-offsets
status.storage.topic=_connect-status

# Replication factors for internal topics
config.storage.replication.factor=1
offset.storage.replication.factor=1
status.storage.replication.factor=1

# REST API configuration
rest.port=8083
rest.host.name=0.0.0.0

# Plugin path
plugin.path=/etc/kafka-connect/plugins

# Converters
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=false
value.converter.schemas.enable=false

# Internal key and value converters
internal.key.converter=org.apache.kafka.connect.json.JsonConverter
internal.value.converter=org.apache.kafka.connect.json.JsonConverter
internal.key.converter.schemas.enable=false
internal.value.converter.schemas.enable=false
EOF
        chmod 644 ./kafka/connect-distributed.properties
        log_success "Basic Kafka Connect configuration created"
    fi
    
    log_info "Directory structure created:"
    tree . -I 'node_modules|.git' -L 3 2>/dev/null || find . -type d -not -path "./.git*" | head -20
}

# Install Docker and Docker Compose (same as before)
install_docker() {
    log_info "Installing Docker and Docker Compose..."
    
    # Check if running in WSL
    if grep -q Microsoft /proc/version 2>/dev/null; then
        log_info "WSL 2 environment detected"
        WSL_ENV=true
    else
        WSL_ENV=false
    fi
    
    if [ "$WSL_ENV" = true ]; then
        log_warning "WSL 2 detected. Checking Docker Desktop integration..."
        
        if command -v docker > /dev/null 2>&1 && docker info > /dev/null 2>&1; then
            log_success "Docker is accessible via WSL integration"
        else
            log_error "Docker Desktop WSL integration not configured"
            log_info "Please enable WSL integration in Docker Desktop settings:"
            log_info "1. Open Docker Desktop on Windows"
            log_info "2. Go to Settings → Resources → WSL Integration"
            log_info "3. Enable integration with your WSL distro"
            log_info "4. Apply & Restart Docker Desktop"
            log_info "5. Restart your WSL terminal"
            exit 1
        fi
        
        # Check if docker compose plugin is available
        if docker compose version > /dev/null 2>&1; then
            log_success "Docker Compose plugin is available"
        else
            log_error "Docker Compose plugin not available - please update Docker Desktop"
            exit 1
        fi
        
        log_success "Docker setup completed for WSL 2"
        return
    fi
    
    if command -v docker > /dev/null 2>&1 && docker compose version > /dev/null 2>&1; then
        log_success "Docker and Docker Compose are already installed"
        return
    fi
    
    # Remove old Docker versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install dependencies
    sudo apt install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Install standalone docker-compose
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker and Docker Compose installed"
    
    # Apply group changes immediately and test Docker access
    log_info "Applying Docker group changes and testing access..."
    
    # First test current access
    if docker ps > /dev/null 2>&1; then
        log_success "Docker access already working"
    else
        log_info "Docker access needs group permissions - applying fix..."
        
        # Try to apply group changes immediately
        if command -v newgrp > /dev/null 2>&1; then
            log_info "Trying newgrp docker to apply group changes..."
            # Test if newgrp helps
            if sg docker -c "docker ps" > /dev/null 2>&1; then
                log_success "Docker access working with group permissions"
                log_warning "IMPORTANT: Run 'newgrp docker' or restart your terminal for persistent access"
            else
                log_warning "Group changes not taking effect immediately"
                log_info "Please restart your terminal/WSL session and run the script again"
                log_info "Or temporarily use: sudo docker commands"
                exit 1
            fi
        else
            log_warning "Please restart your terminal/WSL session for Docker group changes to take effect"
            exit 1
        fi
    fi
}

# Check Docker Compose configuration
check_docker_compose() {
    log_info "Checking Docker Compose configuration..."
   
    if [ ! -f "docker-compose-dev.yml" ] && [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ]; then
        log_error "No docker-compose files found in current directory"
        return 1
    fi
   
    if [ -f "docker-compose-dev.yml" ]; then
        COMPOSE_FILE="docker-compose-dev.yml"
    elif [ -f "docker-compose.yml" ]; then
        COMPOSE_FILE="docker-compose.yml"
    elif [ -f "docker-compose.yaml" ]; then
        COMPOSE_FILE="docker-compose.yaml"
    fi
   
    log_success "Found $COMPOSE_FILE - ready for Docker services"
    export COMPOSE_FILE
}

install_utilities() {
    # Install essential utilities
    sudo apt install -y jq curl wget git tree

    # Install MinIO client if not present
    if ! command -v mc > /dev/null 2>&1; then
        log_info "Installing MinIO client (mc)..."
        curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
        chmod +x mc
        sudo mv mc /usr/local/bin/
        log_success "MinIO client installed"
    fi
   
    log_success "Utilities installed"
}   

# Health check function (same as before - no changes needed)
check_env_health() {
    log_info "Performing environment health check..."
    
    local errors=0
    
    # Check Java
    if command -v java > /dev/null 2>&1; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1)
        log_success "Java: $JAVA_VERSION"
    else
        log_error "Java not found"
        errors=$((errors + 1))
    fi
    
    # Check Scala
    if command -v scala > /dev/null 2>&1; then
        SCALA_VERSION=$(scala -version 2>&1 | head -n 1)
        log_success "Scala: $SCALA_VERSION"
    else
        log_error "Scala not found"
        errors=$((errors + 1))
    fi
    
    # Check SBT
    if command -v sbt > /dev/null 2>&1; then
        SBT_VERSION=$(sbt --version 2>/dev/null | tail -n 1)
        log_success "SBT: $SBT_VERSION"
    else
        log_error "SBT not found"
        errors=$((errors + 1))
    fi
    
    # Check Python
    if command -v python > /dev/null 2>&1; then
        PYTHON_VERSION=$(python --version)
        log_success "Python: $PYTHON_VERSION"
    else
        log_error "Python not found"
        errors=$((errors + 1))
    fi
    
    # Check Docker with proper permission handling
    if command -v docker > /dev/null 2>&1; then
        if docker info > /dev/null 2>&1; then
            DOCKER_VERSION=$(docker --version)
            log_success "Docker: $DOCKER_VERSION"
        elif sg docker -c "docker info" > /dev/null 2>&1; then
            DOCKER_VERSION=$(docker --version)
            log_success "Docker: $DOCKER_VERSION (requires group permissions)"
        elif sudo docker info > /dev/null 2>&1; then
            DOCKER_VERSION=$(docker --version)
            log_success "Docker: $DOCKER_VERSION (requires sudo)"
        else
            log_error "Docker is installed but not accessible"
            errors=$((errors + 1))
        fi
    else
        log_error "Docker not found"
        errors=$((errors + 1))
    fi
    
    # Check Docker Compose
    if docker compose version > /dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version)
        log_success "Docker Compose: $COMPOSE_VERSION"
    elif sg docker -c "docker compose version" > /dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version)
        log_success "Docker Compose: $COMPOSE_VERSION (requires group permissions)"
    elif sudo docker compose version > /dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version)
        log_success "Docker Compose: $COMPOSE_VERSION (requires sudo)"
    elif command -v docker-compose > /dev/null 2>&1; then
        COMPOSE_VERSION=$(docker-compose --version)
        log_success "Docker Compose (legacy): $COMPOSE_VERSION"
    else
        log_error "Docker Compose not found"
        errors=$((errors + 1))
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "Environment health check passed!"
        return 0
    else
        log_error "Environment health check failed with $errors errors"
        return 1
    fi
}

# Build and run applications
build_and_run() {
    log_info "Building and running applications..."
    
    # Start Docker services - test permissions and use appropriate method
    if [ -f "docker-compose-dev.yml" ] || [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
        log_info "Starting Docker services (volumes will be created automatically)..."
        
        if docker ps > /dev/null 2>&1; then
            docker compose -f "$COMPOSE_FILE" up -d
            docker compose -f "$COMPOSE_FILE" ps
        elif sg docker -c "docker ps" > /dev/null 2>&1; then
            sg docker -c "docker compose -f '$COMPOSE_FILE' up -d"
            sg docker -c "docker compose -f '$COMPOSE_FILE' ps"
        else
            sudo docker compose -f "$COMPOSE_FILE" up -d
            sudo docker compose -f "$COMPOSE_FILE" ps
        fi
        
        log_success "Docker services started with auto-created volumes"
    fi
        
    # Build Scala/SBT project if build.sbt exists (check in parent directory)
    if [ -f "../build.sbt" ]; then
        log_info "Building SBT project..."
        (cd .. && sbt clean compile)
        log_success "SBT project built successfully"
        
        # Optionally run the application
        echo
        read -p "Do you want to run the Scala application now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Running Scala application..."
            (cd .. && sbt run)
        fi
    fi
    
    # Install Python dependencies if requirements.txt exists
    if [ -f "requirements.txt" ] || [ -f "../requirements.txt" ]; then
        log_info "Installing Python dependencies..."
        if [ -f "requirements.txt" ]; then
            pip3 install -r requirements.txt
        else
            pip3 install -r ../requirements.txt
        fi
        log_success "Python dependencies installed"
        
        # Look for common Python entry points
        for py_file in "main.py" "../main.py" "app.py" "../app.py"; do
            if [ -f "$py_file" ]; then
                echo
                read -p "Do you want to run $(basename $py_file)? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    log_info "Running Python application..."
                    python "$py_file"
                    break
                fi
            fi
        done
    fi
}

init-mqtt-connector() {
    KAFKA_CONNECT_URL="http://localhost:8083"
    CONNECTOR_NAME="mqtt-source-wildcard"

    echo "Creating MQTT Source Connector..."

    # Delete existing connector
    echo "Deleting existing connector (if exists)..."
    curl -X DELETE "$KAFKA_CONNECT_URL/connectors/$CONNECTOR_NAME" 2>/dev/null || echo "No existing connector found"

    sleep 2

    # Create new connector
    echo "Creating new connector..."
    curl -X POST -H "Content-Type: application/json" \
        -d @- "$KAFKA_CONNECT_URL/connectors" <<-EOF
    {
        "name": "mqtt-source-wildcard",
        "config": {
            "connector.class": "io.lenses.streamreactor.connect.mqtt.source.MqttSourceConnector",
            "tasks.max": "1",
            "connect.mqtt.hosts": "tcp://smartstar-mosquitto-mqtt:1883",
            "connect.mqtt.service.quality": "1",
            "connect.mqtt.client.id": "kafka-connect-mqtt-multi",
            "connect.mqtt.connection.timeout": "30000",
            "connect.mqtt.connection.keep.alive": "60000",
            "connect.mqtt.connection.clean.session": "true",
            "connect.mqtt.kcql": "INSERT INTO sensors.temperature SELECT * FROM \`sensors/temperature\/+\` WITHKEY(device_id, timestamp); INSERT INTO sensors.air_quality SELECT * FROM \`sensors/air_quality/+\` WITHKEY(device_id, timestamp); INSERT INTO sensors.motion SELECT * FROM \`sensors/motion/+\` WITHKEY(device_id, timestamp);",
            "key.converter": "org.apache.kafka.connect.storage.StringConverter",
            "value.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",
            "key.converter.schemas.enable": "false",
            "value.converter.schemas.enable": "false"
        }
    }
EOF

    echo ""
    echo "Connector creation request sent!"

    sleep 5

    # Check status
    echo "Checking connector status..."
    curl -s "$KAFKA_CONNECT_URL/connectors/$CONNECTOR_NAME/status" | jq '.' || curl -s "$KAFKA_CONNECT_URL/connectors/$CONNECTOR_NAME/status"

    echo ""
    echo "All connectors:"
    curl -s "$KAFKA_CONNECT_URL/connectors"

    echo ""
    echo "Setup complete!"
}

init-s3-bucket() {
    mc alias set local $MINIO_ENDPOINT $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
    log_info "Initializing MinIO S3 bucket..."

    # Wait for MinIO to be ready
    log_info "Waiting for MinIO to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/minio/health/live | grep -q "200"; then
            log_success "MinIO is ready"
            break
        else
            log_info "Attempt $attempt/$max_attempts: Waiting for MinIO..."
            sleep 2
            attempt=$((attempt + 1))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "MinIO did not become ready within timeout"
        return 1
    fi

    # Create bucket if it doesn't exist
    if ! mc alias list | grep -q "local"; then
        mc alias set local http://localhost:9000 minioadmin minioadmin
    fi

    if ! mc ls local/$BUCKET_NAME >/dev/null 2>&1; then
        log_info "Creating bucket '$BUCKET_NAME'..."
        mc mb local/$BUCKET_NAME
        log_success "Bucket '$BUCKET_NAME' created"
    else
        log_success "Bucket '$BUCKET_NAME' already exists"
    fi
}

# Main execution
main() {
    log_info "Starting local development stack setup for Ubuntu 22.04+..."
    
    # Handle cleanup option first
    if [ "$1" = "cleanup" ] || [ "$1" = "--cleanup" ]; then
        verify_working_directory
        interactive_cleanup
        exit 0
    fi

    # Verify we're in the correct directory
    verify_working_directory

    check_ubuntu_version
    update_system
    install_utilities
    install_java
    install_scala
    install_sbt
    install_python
    install_docker
    
    # Source bashrc to get new PATH
    source ~/.bashrc 2>/dev/null || true
    
    # Wait a moment for services to initialize
    sleep 5
    
    create_service_directories

    check_docker_compose
    
    if check_env_health; then
        build_and_run
        log_success "Setup completed successfully!"
    else
        log_error "Setup completed with errors. Please check the output above."
        exit 1
    fi
    
    # Wait a bit for Kafka Connect to be fully up
    log_info "Waiting for the environment to be fully up..."
    sleep 10
    log_info "Initializing Kafka Connect plugins and connectors..."
    init-mqtt-connector

    log_info "Initializing s3 bucket..."
    init-s3-bucket

    log_success "All done! You can now start developing your applications."
    log_info "Note: If Docker commands fail, you may need to log out and back in"
}

# Run main function
main "$@"