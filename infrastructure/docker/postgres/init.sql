-- SmartStar PostgreSQL Initialization Script
-- Creates databases and schemas for Iceberg catalog and application data

-- Create additional databases
CREATE DATABASE iceberg;
CREATE DATABASE analytics;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE iceberg TO smartstar;
GRANT ALL PRIVILEGES ON DATABASE analytics TO smartstar;

-- Connect to iceberg database and create schema
\c iceberg

-- Iceberg JDBC catalog tables will be auto-created by Spark
-- But we prepare the schema
CREATE SCHEMA IF NOT EXISTS iceberg_catalog;
GRANT ALL ON SCHEMA iceberg_catalog TO smartstar;

-- Connect back to main database
\c smartstar

-- Application schemas
CREATE SCHEMA IF NOT EXISTS sensors;
CREATE SCHEMA IF NOT EXISTS events;
CREATE SCHEMA IF NOT EXISTS metadata;

-- Sensor metadata table
CREATE TABLE IF NOT EXISTS metadata.sensors (
    sensor_id VARCHAR(64) PRIMARY KEY,
    sensor_type VARCHAR(32) NOT NULL,
    location_name VARCHAR(128),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    installed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP,
    status VARCHAR(16) DEFAULT 'active',
    metadata JSONB
);

-- Topic registry
CREATE TABLE IF NOT EXISTS metadata.topics (
    topic_name VARCHAR(128) PRIMARY KEY,
    schema_version VARCHAR(16),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default topics
INSERT INTO metadata.topics (topic_name, schema_version, description) VALUES
    ('sensors.temperature', 'v1', 'Temperature and humidity sensor readings'),
    ('sensors.motion', 'v1', 'Motion detection events'),
    ('sensors.air_quality', 'v1', 'Air quality measurements (PM2.5, CO2, AQI)'),
    ('sensors.smart_meter', 'v1', 'Power consumption readings'),
    ('events.user', 'v1', 'User activity events'),
    ('events.system', 'v1', 'System events and alerts')
ON CONFLICT (topic_name) DO NOTHING;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sensors_type ON metadata.sensors(sensor_type);
CREATE INDEX IF NOT EXISTS idx_sensors_status ON metadata.sensors(status);

