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

# ==============================================================================
# CONFIGURATION VARIABLES - Modify these as needed
# ==============================================================================

# Version configurations
CONNECTOR_VERSION="${CONNECTOR_VERSION:-10.0.0}"

# GitHub and external service URLs
GITHUB_BASE_URL="${GITHUB_BASE_URL:-https://github.com}"
STREAM_REACTOR_BASE_URL="${STREAM_REACTOR_BASE_URL:-${GITHUB_BASE_URL}/lensesio/stream-reactor/releases/download}"
COURSIER_DOWNLOAD_URL="${COURSIER_DOWNLOAD_URL:-${GITHUB_BASE_URL}/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz}"
DOCKER_COMPOSE_RELEASES_URL="${DOCKER_COMPOSE_RELEASES_URL:-https://api.github.com/repos/docker/compose/releases/latest}"
DOCKER_COMPOSE_DOWNLOAD_URL="${DOCKER_COMPOSE_DOWNLOAD_URL:-${GITHUB_BASE_URL}/docker/compose/releases/download}"

# Docker repository URLs
DOCKER_DOWNLOAD_BASE="${DOCKER_DOWNLOAD_BASE:-https://download.docker.com/linux/ubuntu}"
DOCKER_GPG_URL="${DOCKER_GPG_URL:-${DOCKER_DOWNLOAD_BASE}/gpg}"
DOCKER_REPO_URL="${DOCKER_REPO_URL:-${DOCKER_DOWNLOAD_BASE}}"

# MinIO URLs
MINIO_BASE_URL="${MINIO_BASE_URL:-https://dl.min.io}"
MINIO_CLIENT_URL="${MINIO_CLIENT_URL:-${MINIO_BASE_URL}/client/mc/release/linux-amd64/mc}"

# SBT and Scala repository URLs
SBT_KEYSERVER_BASE="${SBT_KEYSERVER_BASE:-https://keyserver.ubuntu.com}"
SBT_KEYSERVER_URL="${SBT_KEYSERVER_URL:-${SBT_KEYSERVER_BASE}/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823}"
SBT_REPO_BASE="${SBT_REPO_BASE:-https://repo.scala-sbt.org/scalasbt/debian}"
SBT_REPO_MAIN="${SBT_REPO_MAIN:-${SBT_REPO_BASE} all main}"
SBT_REPO_OLD="${SBT_REPO_OLD:-${SBT_REPO_BASE} /}"

# Service endpoint configurations
LOCALHOST_BASE="${LOCALHOST_BASE:-localhost}"
KAFKA_CONNECT_URL="${KAFKA_CONNECT_URL:-http://${LOCALHOST_BASE}:8083}"
KAFKA_BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_SERVERS:-${LOCALHOST_BASE}:9092}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://${LOCALHOST_BASE}:9000}"
MINIO_HEALTH_URL="${MINIO_HEALTH_URL:-http://${LOCALHOST_BASE}:9000/minio/health/live}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-minioadmin}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-minioadmin}"
BUCKET_NAME="${BUCKET_NAME:-smartstar}"

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
    MAJOR_VERSION=$(echo "$VERSION" | cut -d '.' -f 1)
    MINOR_VERSION=$(echo "$VERSION" | cut -d '.' -f 2)
    
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
        if docker stop "$RUNNING_CONTAINERS" 2>/dev/null; then
            log_info "Stopped running containers"
        elif sg docker -c "docker stop $RUNNING_CONTAINERS" 2>/dev/null; then
            log_info "Stopped running containers with sg docker"
        elif sudo docker stop "$RUNNING_CONTAINERS" 2>/dev/null; then
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
        PID=$(sudo lsof -ti ":$port" 2>/dev/null)
        if [ -n "$PID" ]; then
            log_info "Killing process $PID using port $port"
            sudo kill -9 "$PID" 2>/dev/null || true
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
    # Use glob pattern instead of ls | grep for better file handling
    if ls -d ./mosquitto ./kafka ./minio ./postgres 2>/dev/null; then
        log_info "Some service directories still exist"
    else
        log_info "All service directories removed"
    fi
    
    log_success "Environment cleanup completed!"
    log_info "You can now run the setup script again with a clean environment"
}

# Interactive cleanup function
interactive_cleanup() {
    log_warning "This will completely remove all Docker containers, volumes, and service data!"
    echo -n "Are you sure you want to proceed? (y/N): "
    read -r response

    case "$response" in
        [yY][eE][sS]|[yY])
            cleanup_environment
            ;;
        *)
            log_info "Cleanup cancelled"
            ;;
    esac
}

# Legacy main function - removed to avoid conflicts

cleanup() {
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
    curl -fL "$COURSIER_DOWNLOAD_URL" | gzip -d > cs
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
    
    echo "deb $SBT_REPO_MAIN" | sudo tee /etc/apt/sources.list.d/sbt.list
    echo "deb $SBT_REPO_OLD" | sudo tee /etc/apt/sources.list.d/sbt_old.list
    curl -sL "$SBT_KEYSERVER_URL" | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/sbt.gpg > /dev/null
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
install_awscli_v2() {
  echo ">>> Removing any old AWS CLI v1 from apt..."
  if dpkg -l | grep -q awscli; then
    sudo apt remove -y awscli
  else
    echo "No apt-based awscli found, skipping removal."
  fi

  echo ">>> Downloading AWS CLI v2 installer..."
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

  echo ">>> Unzipping installer..."
  unzip -qq awscliv2.zip &

  echo ">>> Installing AWS CLI v2..."
  sudo ./aws/install --update

  echo ">>> Cleaning up temporary files..."
  rm -rf awscliv2.zip aws/

  echo ">>> Checking installed version..."
  aws --version
}

download-mqtt-kafka-connector() {
    log_info "Downloading Kafka Connect MQTT Connector..."
    CONNECTOR_VERSION="10.0.0"
    DOWNLOAD_URL="${STREAM_REACTOR_BASE_URL}/${CONNECTOR_VERSION}/kafka-connect-mqtt-${CONNECTOR_VERSION}.zip"
    TEMP_DIR="/tmp/kafka-connect-mqtt-$$"
    LIBS_DIR="../libs"

    # Ensure we're in the right directory or create paths relative to current location
    if [ ! -d "smartstar" ]; then
        log_info "Creating smartstar directory structure..."
        mkdir -p "$LIBS_DIR"
    fi

    log_info "Downloading Kafka Connect MQTT connector v${CONNECTOR_VERSION}..."

    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"

    # Download the connector
    if curl -L -o "kafka-connect-mqtt-${CONNECTOR_VERSION}.zip" "$DOWNLOAD_URL"; then
        log_success "Download completed"
    else
        log_error "Failed to download connector"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Unzip the connector
    log_info "Extracting connector..."
    if unzip -q "kafka-connect-mqtt-${CONNECTOR_VERSION}.zip"; then
        log_success "Extraction completed"
    else
        log_error "Failed to extract connector"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Find the assembly JAR file
    log_info "Looking for assembly JAR file..."
    ASSEMBLY_JAR=$(find . -name "*assembly*.jar" -type f | head -n 1)

    if [ -z "$ASSEMBLY_JAR" ]; then
        log_error "Assembly JAR file not found"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    log_info "Found assembly JAR: $(basename "$ASSEMBLY_JAR")"

    # Go back to original directory
    cd - > /dev/null

    # Copy the assembly JAR to libs directory
    log_info "Copying assembly JAR to $LIBS_DIR..."
    if cp "$TEMP_DIR/$ASSEMBLY_JAR" "$LIBS_DIR/"; then
        log_success "JAR file copied to $LIBS_DIR/$(basename "$ASSEMBLY_JAR")"
    else
        log_error "Failed to copy JAR file"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Cleanup temporary directory
    log_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"

    log_success "Kafka Connect MQTT connector installation completed!"
    log_info "JAR location: $LIBS_DIR/$(basename "$ASSEMBLY_JAR")"

    # List the libs directory contents
    if [ -d "$LIBS_DIR" ]; then
        log_info "Contents of $LIBS_DIR:"
        ls -la "$LIBS_DIR"
    fi
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
        "../libs/kafka-connect-mqtt-assembly-10.0.0.jar" 
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
    curl -fsSL "$DOCKER_GPG_URL" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $DOCKER_REPO_URL $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Install standalone docker-compose
    DOCKER_COMPOSE_VERSION=$(curl -s "$DOCKER_COMPOSE_RELEASES_URL" | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "${DOCKER_COMPOSE_DOWNLOAD_URL}/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
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
        curl -O "$MINIO_CLIENT_URL"
        chmod +x mc
        sudo mv mc /usr/local/bin/
        log_success "MinIO client installed"
    fi
    # Install AWS CLI v2
    install_awscli_v2
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
        if curl -s -o /dev/null -w "%{http_code}" "$MINIO_HEALTH_URL" | grep -q "200"; then
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
        mc alias set local "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"
    fi

    if ! mc ls local/$BUCKET_NAME >/dev/null 2>&1; then
        log_info "Creating bucket '$BUCKET_NAME'..."
        mc mb local/$BUCKET_NAME
        log_success "Bucket '$BUCKET_NAME' created"
    else
        log_success "Bucket '$BUCKET_NAME' already exists"
    fi
}

# Create Kafka topics for the streaming pipeline
create_kafka_topics() {
    log_info "Creating Kafka topics..."
    kafka_container="smartstar-kafka-broker"
    local bootstrap_servers="$KAFKA_BOOTSTRAP_SERVERS"
    local max_attempts=30
    local attempt=1

    # Wait for Kafka to be ready
    log_info "Waiting for Kafka to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if docker exec $kafka_container /opt/kafka/bin/kafka-topics.sh --bootstrap-server $bootstrap_servers --list > /dev/null 2>&1; then
            log_success "Kafka is ready"
            break
        else
            log_info "Attempt $attempt/$max_attempts: Waiting for Kafka..."
            sleep 2
            attempt=$((attempt + 1))
        fi
    done

    if [ $attempt -gt $max_attempts ]; then
        log_error "Kafka did not become ready within timeout"
        return 1
    fi

    # Define topics to create
    local topics=(
        "sensors.temperature:3:1"
        "sensors.air_quality:3:1"
        "sensors.motion:3:1"
    )

    # Create each topic
    for topic_config in "${topics[@]}"; do
        IFS=':' read -r topic_name partitions replication <<< "$topic_config"

        log_info "Creating topic: $topic_name (partitions=$partitions, replication=$replication)"

        if docker exec $kafka_container /opt/kafka/bin/kafka-topics.sh \
            --bootstrap-server $bootstrap_servers \
            --create \
            --topic "$topic_name" \
            --partitions "$partitions" \
            --replication-factor "$replication" \
            --if-not-exists > /dev/null 2>&1; then
            log_success "Topic '$topic_name' created successfully"
        else
            log_warning "Topic '$topic_name' might already exist or creation failed"
        fi
    done

    # List all topics to verify
    log_info "Current Kafka topics:"
    if docker exec $kafka_container /opt/kafka/bin/kafka-topics.sh --bootstrap-server $bootstrap_servers --list; then
        log_success "Kafka topics creation completed"
    else
        log_error "Failed to list Kafka topics"
        return 1
    fi

    # Optional: Show topic details
    log_info "Topic details:"
    for topic_config in "${topics[@]}"; do
        IFS=':' read -r topic_name partitions replication <<< "$topic_config"
        echo "Topic: $topic_name"
        docker exec $kafka_container /opt/kafka/bin/kafka-topics.sh \
            --bootstrap-server $bootstrap_servers \
            --describe \
            --topic "$topic_name" 2>/dev/null || true
        echo "---"
    done
}

build_and_push_iceberg_runtime() {
  local SPARK_VERSION="4.0"                   # adjust to your Spark minor version (3.4, 3.5…)
  local SCALA_VERSION="2.13"                  # Scala version
  local ICEBERG_BRANCH="main"                 # branch or tag, e.g. release-1.10.0
  local WORKDIR="/tmp/iceberg-build"          # temporary build location
  local S3_BUCKET="s3://smartstar/"       # replace with your bucket
  local ICEBERG_RELEASE="1.10.0-rc4"
  local ARTIFACT_NAME="iceberg-spark-runtime-${SPARK_VERSION}_${SCALA_VERSION}-1.11.0-SNAPSHOT.jar"
  local S3_ENDPOINT="http://localhost:9000"

  echo ">>> Cloning Iceberg repo..."
  rm -rf "$WORKDIR"
  git clone --branch "$ICEBERG_BRANCH" https://github.com/apache/iceberg.git "$WORKDIR"

  cd "$WORKDIR" || exit 1

  git checkout -b apache-iceberg-${ICEBERG_RELEASE}

  echo ">>> Building Spark runtime for Spark ${SPARK_VERSION} and Scala ${SCALA_VERSION}..."
  #./gradlew spotlessApply
  ./gradlew :iceberg-spark:iceberg-spark-runtime-4.0_2.13:assemble -x test
  ./gradlew :iceberg-spark:iceberg-spark-runtime-4.0_2.13:publishToMavenLocal -x test

  local JAR_PATH="spark/v${SPARK_VERSION}/spark-runtime/build/libs/${ARTIFACT_NAME}"

  if [[ ! -f "$JAR_PATH" ]]; then
    echo "Build failed: $JAR_PATH not found"
    exit 1
  fi

  echo ">>> Uploading $ARTIFACT_NAME to $S3_BUCKET ..."
  aws s3 cp "$JAR_PATH" "$S3_BUCKET/libs/$ARTIFACT_NAME" --acl --endpoint $S3_ENDPOINT bucket-owner-full-control

  echo ">>> Done. Artifact available at $S3_BUCKET/$ARTIFACT_NAME"
}
# Interactive menu function
show_menu() {
    echo
    log_info "Local Development Stack Setup - Choose an option:"
    echo "1) cleanup   - Clean up all containers, volumes, and data directories"
    echo "2) setup     - Run complete setup (install dependencies + start services)"
    echo "3) test      - Run a single function for testing"
    echo "4) all       - Run everything (setup + initialize connectors + S3 bucket)"
    echo
    read -p "Select option (1-4): " -n 1 -r
    echo
    return $REPLY
}

# Function to test individual functions
test_function() {
    echo
    log_info "Available functions to test:"
    echo "1) check_ubuntu_version"
    echo "2) install_java"
    echo "3) install_scala" 
    echo "4) install_sbt"
    echo "5) install_python"
    echo "6) install_docker"
    echo "7) create_service_directories"
    echo "8) check_env_health"
    echo "9) init-mqtt-connector"
    echo "10) init-s3-bucket"
    echo "11) download-mqtt-kafka-connector"
    echo "12) create_kafka_topics"
    echo "13) build_and_push_iceberg_runtime"
    echo "14) install_utilities"
    read -p "Select function to test (1-14): " -n 2 -r
    echo
    
    case $REPLY in
        1) check_ubuntu_version ;;
        2) install_java ;;
        3) install_scala ;;
        4) install_sbt ;;
        5) install_python ;;
        6) install_docker ;;
        7) create_service_directories ;;
        8) check_env_health ;;
        9) init-mqtt-connector ;;
        10) init-s3-bucket ;;
        11) download-mqtt-kafka-connector ;;
        12) create_kafka_topics ;;
        13) build_and_push_iceberg_runtime ;;
        14) install_utilities ;;
        *) log_error "Invalid function selection"; exit 1 ;;
    esac
}

main() {
    log_info "Starting local development stack setup for Ubuntu 22.04+..."
    
    # Handle command line arguments
    case "${1:-}" in
        "cleanup"|"--cleanup")
            verify_working_directory
            interactive_cleanup
            exit 0
            ;;
        "setup"|"--setup")
            OPTION="setup"
            ;;
        "test"|"--test")
            verify_working_directory
            if [ -n "${2:-}" ]; then
                # Direct function call: ./script.sh test function_name
                case "$2" in
                    "check_ubuntu_version") check_ubuntu_version ;;
                    "install_java") install_java ;;
                    "install_scala") install_scala ;;
                    "install_sbt") install_sbt ;;
                    "install_python") install_python ;;
                    "install_docker") install_docker ;;
                    "create_service_directories") create_service_directories ;;
                    "check_env_health") check_env_health ;;
                    "init-mqtt-connector") init-mqtt-connector ;;
                    "init-s3-bucket") init-s3-bucket ;;
                    "download-mqtt-kafka-connector") download-mqtt-kafka-connector ;;
                    "create_kafka_topics") create_kafka_topics ;;
                    "build_and_push_iceberg_runtime") build_and_push_iceberg_runtime ;;
                    "install_utilities") install_utilities;;
                    *) log_error "Unknown function: $2"; exit 1 ;;
                esac
            else
                # Interactive function selection
                test_function
            fi
            exit 0
            ;;
        "all"|"--all")
            OPTION="all"
            ;;
        "")
            # No argument provided, show interactive menu
            echo
            log_info "Local Development Stack Setup - Choose an option:"
            echo "1) cleanup   - Clean up all containers, volumes, and data directories"
            echo "2) setup     - Run complete setup (install dependencies + start services)"
            echo "3) test      - Run a single function for testing"
            echo "4) all       - Run everything (setup + initialize connectors + S3 bucket)"
            echo
            read -p "Select option (1-4): " -n 1 -r
            echo
            case $REPLY in
                1) verify_working_directory; interactive_cleanup; exit 0 ;;
                2) OPTION="setup" ;;
                3) verify_working_directory; test_function; exit 0 ;;
                4) OPTION="all" ;;
                *) log_error "Invalid option. Exiting."; exit 1 ;;
            esac
            ;;
        *)
            log_error "Unknown option: $1"
            log_info "Usage: $0 [cleanup|setup|test [function_name]|all]"
            log_info "Example: $0 test install_java"
            exit 1
            ;;
    esac

    # Verify we're in the correct directory
    verify_working_directory

    # Execute based on selected option
    case $OPTION in
        "setup")
            log_info "Running complete setup..."
            check_ubuntu_version
            update_system
            install_utilities
            install_java
            install_scala
            install_sbt
            install_python
            install_docker
            
            source ~/.bashrc 2>/dev/null || true
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
            ;;
        "all")
            log_info "Running full setup with initialization..."
            check_ubuntu_version
            update_system
            install_utilities
            install_java
            install_scala
            install_sbt
            install_python
            install_docker
            
            source ~/.bashrc 2>/dev/null || true
            sleep 5
            
            download-mqtt-kafka-connector
            create_service_directories
            check_docker_compose
            
            if check_env_health; then
                build_and_run
                log_success "Setup completed successfully!"
            else
                log_error "Setup completed with errors. Please check the output above."
                exit 1
            fi
            
            # Initialize connectors and S3 bucket
            log_info "Waiting for the environment to be fully up..."
            sleep 5
            log_info "Configure Kafka Connect plugins and connectors..."
            init-mqtt-connector
            log_info "Create Kafka topics ..."
            create_kafka_topics
            log_info "Create s3 bucket..."
            init-s3-bucket
            log_info "Buil Iceberg spark runtime and push to S3"
            build_and_push_iceberg_runtime
            log_success "All done! You can now start developing your applications."
            ;;
    esac
    
    log_info "Note: If Docker commands fail, you may need to log out and back in, restart the script"
}
# Run main function
main "$@"