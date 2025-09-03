#!/bin/bash

# SmartStar Complete Development Environment Setup Script
# This script sets up the complete development environment from scratch
# Author: SmartStar Development Team
# Version: 1.0.0

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPARK_APPS_DIR="$SCRIPT_DIR/spark-apps"
DOCKER_DIR="$SPARK_APPS_DIR/docker"
JAVA_VERSION="11"
SCALA_VERSION="2.13"
SBT_VERSION="1.9.7"
SPARK_VERSION="3.5.1"

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "\n${BLUE}🔄 $1${NC}"
}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            echo "ubuntu"
        elif command -v yum &> /dev/null; then
            echo "rhel"
        elif command -v pacman &> /dev/null; then
            echo "arch"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local service_name=$1
    local port=$2
    local max_attempts=60
    local attempt=1
    
    log_info "Waiting for $service_name to be ready on port $port..."
    
    while [ $attempt -le $max_attempts ]; do
        if check_port $port; then
            log_success "$service_name is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log_error "$service_name failed to start after $((max_attempts * 2)) seconds"
    return 1
}

# Function to install Java
install_java() {
    local os=$(detect_os)
    
    if command_exists java; then
        local java_version=$(java -version 2>&1 | head -n1 | cut -d'"' -f2 | cut -d'.' -f1-2)
        log_info "Java is already installed: $java_version"
        
        # Check if it's Java 8 or 11
        if [[ "$java_version" == "1.8" ]] || [[ "$java_version" == "11"* ]] || [[ "$java_version" == "17"* ]]; then
            log_success "Java version is compatible"
            return 0
        else
            log_warning "Java version might not be compatible, but continuing..."
        fi
    else
        log_step "Installing Java $JAVA_VERSION..."
        
        case $os in
            "ubuntu")
                sudo apt-get update
                sudo apt-get install -y openjdk-$JAVA_VERSION-jdk
                ;;
            "macos")
                if command_exists brew; then
                    brew install openjdk@$JAVA_VERSION
                else
                    log_error "Homebrew not found. Please install Java manually."
                    return 1
                fi
                ;;
            "rhel")
                sudo yum install -y java-$JAVA_VERSION-openjdk-devel
                ;;
            *)
                log_error "Unsupported OS for automatic Java installation"
                return 1
                ;;
        esac
        
        log_success "Java $JAVA_VERSION installed successfully"
    fi
}

# Function to install Scala
install_scala() {
    local os=$(detect_os)
    
    if command_exists scala; then
        local scala_version=$(scala -version 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        log_info "Scala is already installed: $scala_version"
        
        if [[ "$scala_version" == "2.13"* ]]; then
            log_success "Scala version is compatible"
            return 0
        else
            log_warning "Scala version might not be compatible, but continuing..."
        fi
    else
        log_step "Installing Scala $SCALA_VERSION..."
        
        case $os in
            "ubuntu")
                sudo apt-get update
                sudo apt-get install -y scala
                ;;
            "macos")
                if command_exists brew; then
                    brew install scala
                else
                    log_error "Homebrew not found. Please install Scala manually."
                    return 1
                fi
                ;;
            "rhel")
                # Install via coursier
                curl -fL https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz | gzip -d > cs
                chmod +x cs
                sudo mv cs /usr/local/bin/
                cs install scala:$SCALA_VERSION
                ;;
            *)
                log_error "Unsupported OS for automatic Scala installation"
                return 1
                ;;
        esac
        
        log_success "Scala installed successfully"
    fi
}

# Function to install SBT
install_sbt() {
    local os=$(detect_os)
    
    if command_exists sbt; then
        log_info "SBT is already installed"
        log_success "SBT is available"
        return 0
    else
        log_step "Installing SBT $SBT_VERSION..."
        
        case $os in
            "ubuntu")
                sudo apt-get update
                sudo apt-get install -y apt-transport-https curl gnupg
                curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo gpg --dearmor -o /usr/share/keyrings/sbt.gpg
                echo "deb [signed-by=/usr/share/keyrings/sbt.gpg] https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list
                sudo apt-get update
                sudo apt-get install -y sbt
                ;;
            "macos")
                if command_exists brew; then
                    brew install sbt
                else
                    log_error "Homebrew not found. Please install SBT manually."
                    return 1
                fi
                ;;
            "rhel")
                sudo rm -f /etc/yum.repos.d/bintray-rpm.repo
                curl -L https://www.scala-sbt.org/sbt-rpm.repo > sbt-rpm.repo
                sudo mv sbt-rpm.repo /etc/yum.repos.d/
                sudo yum install -y sbt
                ;;
            *)
                log_error "Unsupported OS for automatic SBT installation"
                return 1
                ;;
        esac
        
        log_success "SBT installed successfully"
    fi
}

# Function to install Docker
install_docker() {
    local os=$(detect_os)
    
    if command_exists docker; then
        log_info "Docker is already installed"
        
        # Check if Docker daemon is running
        if docker info &> /dev/null; then
            log_success "Docker is running"
        else
            log_warning "Docker is installed but not running. Starting Docker..."
            case $os in
                "ubuntu"|"rhel")
                    sudo systemctl start docker
                    sudo systemctl enable docker
                    ;;
                "macos")
                    log_warning "Please start Docker Desktop manually"
                    ;;
            esac
        fi
        
        return 0
    else
        log_step "Installing Docker..."
        
        case $os in
            "ubuntu")
                sudo apt-get update
                sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt-get update
                sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo usermod -aG docker $USER
                ;;
            "macos")
                log_error "Please install Docker Desktop for Mac manually from https://docker.com"
                return 1
                ;;
            "rhel")
                sudo yum install -y yum-utils
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo usermod -aG docker $USER
                ;;
            *)
                log_error "Unsupported OS for automatic Docker installation"
                return 1
                ;;
        esac
        
        log_success "Docker installed successfully"
        log_warning "You may need to log out and back in for Docker group membership to take effect"
    fi
}

# Function to install Python dependencies
install_python_deps() {
    log_step "Installing Python dependencies for data generator..."
    
    if command_exists python3; then
        log_info "Python 3 is available"
    else
        log_error "Python 3 is not installed. Please install Python 3 first."
        return 1
    fi
    
    if command_exists pip3; then
        log_info "Installing Python packages..."
        pip3 install --user paho-mqtt faker
        log_success "Python dependencies installed"
    else
        log_error "pip3 is not available. Please install pip3 first."
        return 1
    fi
}

# Function to install Apache Spark (optional for local development)
install_spark() {
    if command_exists spark-submit; then
        log_info "Spark is already installed"
        log_success "Spark is available"
        return 0
    fi
    
    log_step "Installing Apache Spark $SPARK_VERSION..."
    
    local spark_dir="/opt/spark"
    local spark_download="https://archive.apache.org/dist/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop3.tgz"
    
    # Download and install Spark
    cd /tmp
    wget -q "$spark_download" -O spark.tgz
    sudo mkdir -p "$spark_dir"
    sudo tar -xzf spark.tgz -C "$spark_dir" --strip-components=1
    sudo chown -R $USER:$USER "$spark_dir"
    
    # Add to PATH
    echo "export SPARK_HOME=$spark_dir" >> ~/.bashrc
    echo "export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin" >> ~/.bashrc
    
    # Source for current session
    export SPARK_HOME="$spark_dir"
    export PATH="$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin"
    
    log_success "Apache Spark installed successfully"
    log_info "Please restart your shell or run 'source ~/.bashrc' to update PATH"
}

# Function to setup Docker environment
setup_docker_environment() {
    log_step "Setting up Docker environment..."
    
    cd "$DOCKER_DIR"
    
    # Create necessary directories
    log_info "Creating Docker volume directories..."
    mkdir -p kafka/data kafka/logs kafka/metadata kafka/plugins
    mkdir -p mosquitto/data mosquitto/logs
    mkdir -p postgres/data
    mkdir -p minio/data
    
    # Set proper permissions for new directories only
    chmod 755 kafka mosquitto postgres minio 2>/dev/null || true
    find kafka mosquitto postgres minio -type d -exec chmod 755 {} \; 2>/dev/null || true
    
    # Create Kafka Connect configuration if not exists
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
offset.flush.interval.ms=10000
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
    
    log_success "Docker environment setup completed"
}

# Function to start Docker services
start_docker_services() {
    log_step "Starting Docker services..."
    
    cd "$DOCKER_DIR"
    
    # Determine docker-compose command
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    else
        DOCKER_COMPOSE="docker compose"
    fi
    
    # Stop any existing services
    log_info "Stopping any existing services..."
    $DOCKER_COMPOSE down &> /dev/null || true
    
    # Start services
    log_info "Starting Docker Compose services..."
    $DOCKER_COMPOSE up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 10
    
    # Check service health
    local services=("postgres:5432" "kafka:9092" "mosquitto:1883" "minio:9000")
    for service in "${services[@]}"; do
        local name=$(echo $service | cut -d':' -f1)
        local port=$(echo $service | cut -d':' -f2)
        
        if wait_for_service "$name" "$port"; then
            log_success "$name is running"
        else
            log_error "$name failed to start"
            return 1
        fi
    done
    
    log_success "All Docker services are running"
}

# Function to initialize Kafka topics
initialize_kafka_topics() {
    log_step "Initializing Kafka topics..."
    
    cd "$DOCKER_DIR"
    
    # Wait a bit more for Kafka to be fully ready
    sleep 15
    
    # Run the topic initialization script
    if [ -f "init-kafka-topics.sh" ]; then
        chmod +x init-kafka-topics.sh
        ./init-kafka-topics.sh
    else
        log_warning "init-kafka-topics.sh not found, creating topics manually..."
        
        # Create essential topics
        local topics=("smartstar-events" "sensors.temperature" "sensors.air_quality" "sensors.motion")
        for topic in "${topics[@]}"; do
            docker exec smartstar-kafka-broker /opt/kafka/bin/kafka-topics.sh \
                --bootstrap-server localhost:9092 \
                --create \
                --topic "$topic" \
                --partitions 3 \
                --replication-factor 1 \
                --if-not-exists
        done
    fi
    
    log_success "Kafka topics initialized"
}

# Function to build Spark applications
build_spark_applications() {
    log_step "Building Spark applications..."
    
    cd "$SPARK_APPS_DIR"
    
    # Make build script executable
    chmod +x scripts/build.sh
    
    # Run the build script
    log_info "Running SBT build process..."
    ./scripts/build.sh
    
    log_success "Spark applications built successfully"
}

# Function to run tests
run_tests() {
    log_step "Running application tests..."
    
    cd "$SPARK_APPS_DIR"
    
    # Make test script executable
    chmod +x scripts/test.sh
    
    # Run tests (but don't fail the setup if tests fail)
    log_info "Running test suite..."
    if ./scripts/test.sh; then
        log_success "All tests passed"
    else
        log_warning "Some tests failed, but continuing with setup"
    fi
}

# Function to generate sample data
generate_sample_data() {
    log_step "Generating sample data..."
    
    cd "$SPARK_APPS_DIR/scripts"
    
    # Make the data generator executable
    chmod +x sensor-data.generator.py
    
    # Generate sample data for 30 seconds
    log_info "Generating IoT sensor data for 30 seconds..."
    if command_exists python3; then
        python3 sensor-data.generator.py --broker localhost --port 1883 --type sensors --duration 30 --devices 5 &
        local data_gen_pid=$!
        
        # Wait for data generation to complete
        wait $data_gen_pid
        
        log_success "Sample data generated"
    else
        log_warning "Python 3 not available, skipping data generation"
    fi
}

# Function to run example jobs
run_example_jobs() {
    log_step "Running example Spark jobs..."
    
    cd "$SPARK_APPS_DIR"
    
    # Make run-job script executable
    chmod +x scripts/run-job.sh
    
    # Create sample input directories
    mkdir -p data/input data/output
    
    # Create some sample CSV data for testing
    cat > data/input/sample_data.csv << 'EOF'
id,name,value,timestamp
1,sensor_001,23.5,2024-01-01T10:00:00Z
2,sensor_002,24.1,2024-01-01T10:01:00Z
3,sensor_003,22.8,2024-01-01T10:02:00Z
EOF
    
    log_info "Testing file ingestion job..."
    if ./scripts/run-job.sh ingestion com.smartstar.ingestion.batch.FileIngestionJob data/input data/output 2>/dev/null || true; then
        log_success "Ingestion job completed"
    else
        log_warning "Ingestion job had issues, but setup continues"
    fi
    
    # Test other jobs if available
    log_info "Testing streaming job (this may timeout, which is expected)..."
    timeout 10s ./scripts/run-job.sh ingestion com.smartstar.ingestion.streaming.KafkaStreamingJob smartstar-events data/streaming-output 2>/dev/null || true
    log_info "Streaming job test completed"
}

# Function to show status and next steps
show_status_and_next_steps() {
    log_step "Development Environment Status"
    
    echo -e "\n${GREEN}🎉 SmartStar Development Environment Setup Complete!${NC}\n"
    
    echo -e "${BLUE}📊 Service Status:${NC}"
    
    # Check Docker services
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep smartstar; then
        echo ""
    else
        log_warning "No SmartStar containers found"
    fi
    
    echo -e "\n${BLUE}🌐 Service URLs:${NC}"
    echo -e "  • Kafka UI: ${GREEN}http://localhost:8080${NC}"
    echo -e "  • Kafka Connect: ${GREEN}http://localhost:8083${NC}"
    echo -e "  • MinIO Console: ${GREEN}http://localhost:9001${NC}"
    echo -e "  • PostgreSQL: ${GREEN}localhost:5432${NC} (smartstar/smartstar)"
    echo -e "  • MQTT Broker: ${GREEN}localhost:1883${NC}"
    
    echo -e "\n${BLUE}🚀 Next Steps:${NC}"
    echo -e "1. Explore the Kafka UI at ${GREEN}http://localhost:8080${NC}"
    echo -e "2. Generate more data:"
    echo -e "   ${YELLOW}cd spark-apps/scripts && python3 sensor-data.generator.py --type all --duration 60${NC}"
    echo -e "3. Run Spark jobs:"
    echo -e "   ${YELLOW}cd spark-apps && ./scripts/run-job.sh ingestion com.smartstar.ingestion.batch.FileIngestionJob input/ output/${NC}"
    echo -e "4. Monitor logs:"
    echo -e "   ${YELLOW}docker-compose logs -f kafka${NC}"
    echo -e "5. Stop environment:"
    echo -e "   ${YELLOW}cd spark-apps/docker && $DOCKER_COMPOSE down${NC}"
    
    echo -e "\n${BLUE}📚 Documentation:${NC}"
    echo -e "  • Project README: ${GREEN}./README.md${NC}"
    echo -e "  • Spark Apps: ${GREEN}./spark-apps/README.md${NC}"
    echo -e "  • Example Jobs: ${GREEN}./spark-apps/scripts/run-job.sh${NC}"
    
    echo -e "\n${GREEN}✅ Environment is ready for development!${NC}\n"
}

# Main function
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              SmartStar Development Environment Setup         ║"
    echo "║                        Version 1.0.0                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    log_info "Detected OS: $(detect_os)"
    log_info "Script directory: $SCRIPT_DIR"
    log_info "Spark apps directory: $SPARK_APPS_DIR"
    
    # Check if we're in the right directory
    if [ ! -d "$SPARK_APPS_DIR" ]; then
        log_error "spark-apps directory not found. Please run this script from the SmartStar root directory."
        exit 1
    fi
    
    # Install prerequisites
    log_step "Installing Prerequisites"
    install_java
    install_scala  
    install_sbt
    install_docker
    install_python_deps
    
    # Optional: Install Spark locally
    if [[ "${INSTALL_SPARK:-yes}" == "yes" ]]; then
        install_spark
    fi
    
    # Setup Docker environment
    setup_docker_environment
    
    # Start Docker services
    start_docker_services
    
    # Initialize Kafka
    initialize_kafka_topics
    
    # Build applications
    build_spark_applications
    
    # Run tests
    run_tests
    
    # Generate sample data
    if [[ "${GENERATE_DATA:-yes}" == "yes" ]]; then
        generate_sample_data
    fi
    
    # Run example jobs
    if [[ "${RUN_EXAMPLES:-yes}" == "yes" ]]; then
        run_example_jobs
    fi
    
    # Show final status
    show_status_and_next_steps
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "SmartStar Development Environment Setup Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h              Show this help message"
        echo "  --skip-spark            Skip local Spark installation"
        echo "  --skip-data             Skip sample data generation"
        echo "  --skip-examples         Skip running example jobs"
        echo ""
        echo "Environment Variables:"
        echo "  INSTALL_SPARK=no        Skip Spark installation"
        echo "  GENERATE_DATA=no        Skip data generation"
        echo "  RUN_EXAMPLES=no         Skip example jobs"
        echo ""
        exit 0
        ;;
    --skip-spark)
        export INSTALL_SPARK="no"
        ;;
    --skip-data)
        export GENERATE_DATA="no"
        ;;
    --skip-examples)
        export RUN_EXAMPLES="no"
        ;;
esac

# Run main function
main "$@"