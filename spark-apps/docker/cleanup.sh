#!/bin/bash

# Set base directories (adjust if needed)
KAFKA_DATA="./kafka/data"
KAFKA_LOGS="./kafka/logs"
KAFKA_METADATA="./kafka/metadata"
MOSQUITTO_DATA="./mosquitto/data"
MOSQUITTO_LOGS="./mosquitto/logs"
POSTGRES_DATA="./postgres/data"
MINIO_DATA="./minio/data"

clean_kafka() {
  echo "Cleaning Kafka data, logs, and metadata..."
  rm -rf "$KAFKA_DATA"/* "$KAFKA_LOGS"/* "$KAFKA_METADATA"/*
}

clean_mosquitto() {
  echo "Cleaning Mosquitto data and logs..."
  rm -rf "$MOSQUITTO_DATA"/* "$MOSQUITTO_LOGS"/*
}

clean_postgres() {
  echo "Cleaning Postgres data..."
  rm -rf "$POSTGRES_DATA"/*
}

clean_minio() {
  echo "Cleaning Minio data..."
  rm -rf "$MINIO_DATA"/*
}

clean_all() {
  clean_kafka
  clean_mosquitto
  clean_postgres
  clean_minio
  echo "All data cleaned."
}

# Usage info
usage() {
  echo "Usage: $0 [kafka|mosquitto|postgres|minio|all]"
  exit 1
}

# Main
case "$1" in
  kafka) clean_kafka ;;
  mosquitto) clean_mosquitto ;;
  postgres) clean_postgres ;;
  minio) clean_minio ;;
  all) clean_all ;;
  *) usage ;;
esac