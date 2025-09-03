#!/bin/bash

# Delete the connector if it exists
curl -X DELETE http://localhost:8083/connectors/smartstart-mqtt-source

# Create the connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  --data '{
    "name": "smartstart-mqtt-source",
    "config": {
      "connector.class": "io.lenses.streamreactor.connect.mqtt.source.MqttSourceConnector",
      "tasks.max": "1",
      "connect.mqtt.hosts": "tcp://smartstar-mosquitto-mqtt:1883",
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
  }'