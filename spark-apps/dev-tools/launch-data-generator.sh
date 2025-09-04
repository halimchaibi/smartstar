#!/usr/bin/env bash
set -euo pipefail

# Create build context
mkdir -p data-generator
cp sensor-data.generator.py data-generator/

# Create Dockerfile
cat > data-generator/Dockerfile <<'EOF'
FROM python:3.13-slim

WORKDIR /app

RUN pip install --no-cache-dir \
      paho-mqtt==2.1.0 \
      faker==22.0.0

COPY sensor-data.generator.py .

CMD python sensor-data.generator.py \
    --broker ${MQTT_BROKER:-localhost} \
    --port ${MQTT_PORT:-1883} \
    --type ${DATA_TYPE:-sensors} \
    --duration ${DURATION:-60} \
    --devices ${DEVICE_COUNT:-5}

EOF

echo "✅ Setup complete. Building Docker image 'data-generator'..."

docker build -t data-generator ./data-generator

echo "🚀 Running the data generator container..."

docker run --rm \
  --network docker_smartstar \
  -e MQTT_BROKER=smartstar-mosquitto-mqtt \
  -e MQTT_PORT=1883 \
  -e DATA_TYPE=sensors \
  -e DURATION=300 \
  -e DEVICE_COUNT=5 \
  data-generator
