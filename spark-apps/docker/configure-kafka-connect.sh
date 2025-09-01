#!/bin/bash

# Simple script to create MQTT Connector
KAFKA_CONNECT_URL="http://localhost:8083"
MOSQUITTO_HOST="smartstar-mosquitto-mqtt:1883"
CONNECTOR_NAME="mqtt-source-wildcard"

echo "🚀 Creating MQTT Source Connector..."

# Delete existing connector
echo "🗑️ Deleting existing connector (if exists)..."
curl -X DELETE "$KAFKA_CONNECT_URL/connectors/$CONNECTOR_NAME" 2>/dev/null || echo "No existing connector found"

sleep 2

# Create new connector
echo "🔌 Creating new connector..."
curl -X POST -H "Content-Type: application/json" --data '{
  "name": "mqtt-source-wildcard",
  "config": {
    "connector.class": "io.lenses.streamreactor.connect.mqtt.source.MqttSourceConnector",
    "tasks.max": "1",
    "connect.mqtt.hosts": "tcp://localhost:1883",
    "connect.mqtt.service.quality": "1",
    "connect.mqtt.client.id": "kafka-connect-mqtt-multi",
    "connect.mqtt.connection.timeout": "30000",
    "connect.mqtt.connection.keep.alive": "60000",
    "connect.mqtt.connection.clean.session": "true",
    "connect.mqtt.kcql": "INSERT INTO sensors.temperature SELECT * FROM `sensors/temperature/+` WITHKEY(device_id, timestamp); INSERT INTO sensors.air_quality SELECT * FROM `sensors/air_quality/+` WITHKEY(device_id, timestamp); INSERT INTO sensors.motion SELECT * FROM `sensors/motion/+` WITHKEY(device_id, timestamp);",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",
    "key.converter.schemas.enable": "false",
    "value.converter.schemas.enable": "false"
  }
}' "$KAFKA_CONNECT_URL/connectors"

echo ""
echo "✅ Connector creation request sent!"

sleep 5

# Check status
echo "📊 Checking connector status..."
curl -s "$KAFKA_CONNECT_URL/connectors/$CONNECTOR_NAME/status" | jq '.' || curl -s "$KAFKA_CONNECT_URL/connectors/$CONNECTOR_NAME/status"

echo ""
echo "📋 All connectors:"
curl -s "$KAFKA_CONNECT_URL/connectors"

echo ""
echo "🎉 Setup complete!"