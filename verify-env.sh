#!/bin/bash

# SmartStar Environment Verification Script
# Checks if all services are running and accessible

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

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           SmartStar Environment Verification             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Check Docker containers
log_info "Checking Docker containers..."
if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q smartstar; then
    log_success "SmartStar containers are running"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep smartstar
    echo ""
else
    log_error "No SmartStar containers found running"
    log_info "Run './quick-start.sh' to start the services"
    exit 1
fi

# Check individual services
log_info "Checking service connectivity..."

# Check PostgreSQL
if nc -z localhost 5432 2>/dev/null; then
    log_success "PostgreSQL is accessible on port 5432"
else
    log_warning "PostgreSQL is not accessible on port 5432"
fi

# Check MQTT
if nc -z localhost 1883 2>/dev/null; then
    log_success "MQTT broker is accessible on port 1883"
else
    log_warning "MQTT broker is not accessible on port 1883"
fi

# Check Kafka
if nc -z localhost 9092 2>/dev/null; then
    log_success "Kafka is accessible on port 9092"
else
    log_warning "Kafka is not accessible on port 9092"
fi

# Check MinIO
if nc -z localhost 9000 2>/dev/null; then
    log_success "MinIO is accessible on port 9000"
else
    log_warning "MinIO is not accessible on port 9000"
fi

# Check Kafka UI
if nc -z localhost 8080 2>/dev/null; then
    log_success "Kafka UI is accessible on port 8080"
else
    log_warning "Kafka UI is not accessible on port 8080"
fi

echo ""
log_info "🌐 Service URLs:"
echo -e "  • Kafka UI: ${GREEN}http://localhost:8080${NC}"
echo -e "  • MinIO Console: ${GREEN}http://localhost:9001${NC} (admin/minioadmin)"
echo -e "  • PostgreSQL: ${GREEN}localhost:5432${NC} (smartstar/smartstar)"
echo -e "  • MQTT Broker: ${GREEN}localhost:1883${NC}"

echo ""
log_info "🔧 Development Tools:"
echo -e "  • Generate data: ${YELLOW}cd spark-apps/scripts && python3 sensor-data.generator.py --duration 60${NC}"
echo -e "  • Build apps: ${YELLOW}cd spark-apps && ./scripts/build.sh${NC}"
echo -e "  • Run jobs: ${YELLOW}cd spark-apps && ./scripts/run-job.sh [module] [class] [args]${NC}"

echo ""
log_success "Environment verification completed!"