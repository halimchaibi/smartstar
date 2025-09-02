#!/bin/bash

# Simple script to create Kafka Connect topics
# Modify CONTAINER_NAME to match your Kafka container

CONTAINER_NAME="smartstar-kafka-broker"  # Change this to your container name
BOOTSTRAP_SERVER="localhost:9092"

echo "🚀 Creating Kafka Connect Topics..."

# Create _connect-configs topic
docker exec $CONTAINER_NAME /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --create \
  --topic _connect-configs \
  --partitions 1 \
  --replication-factor 1 \
  --config cleanup.policy=compact \
  --if-not-exists

# Create _connect-offsets topic
docker exec $CONTAINER_NAME /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --create \
  --topic _connect-offsets \
  --partitions 10 \
  --replication-factor 1 \
  --config cleanup.policy=compact \
  --if-not-exists

# Create _connect-status topic
docker exec $CONTAINER_NAME /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --create \
  --topic _connect-status \
  --partitions 5 \
  --replication-factor 1 \
  --config cleanup.policy=compact \
  --if-not-exists

# Create __consumer_offsets topic
docker exec $CONTAINER_NAME /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --create \
  --topic __consumer_offsets \
  --partitions 10 \
  --replication-factor 1 \
  --config cleanup.policy=compact \
  --if-not-exists

# Create __transaction_state topic
docker exec $CONTAINER_NAME /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --create \
  --topic __transaction_state \
  --partitions 10 \
  --replication-factor 1 \
  --config cleanup.policy=compact \
  --if-not-exists

docker exec $CONTAINER_NAME /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --create \
  --topic __cluster_metadata \
  --partitions 10 \
  --replication-factor 1 \
  --config cleanup.policy=compact \
  --if-not-exists

echo "✅ Topics created!"

# List all topics
echo "📋 Current topics:"
docker exec $CONTAINER_NAME /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --list | sort