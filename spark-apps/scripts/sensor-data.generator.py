#!/usr/bin/env python3
"""
MQTT Synthetic Data Generator
Generates realistic IoT sensor data and publishes to MQTT broker
"""

from decimal import Decimal
import json
import time
import random
import uuid
from datetime import datetime, timezone
import paho.mqtt.client as mqtt
from faker import Faker
import threading
import argparse

fake = Faker()

class MQTTDataGenerator:
    def __init__(self, broker_host="localhost", broker_port=1883):
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.connected = False
        
        # Create MQTT client with new callback API
        self.client = mqtt.Client(
            client_id=f"data_generator_{uuid.uuid4()}",
            callback_api_version=mqtt.CallbackAPIVersion.VERSION2
        )
        
        # Set up callbacks
        self.client.on_connect = self.on_connect
        self.client.on_publish = self.on_publish
        self.client.on_disconnect = self.on_disconnect
        self.client.on_connect_fail = self.on_connect_fail
        
    def on_connect(self, client, userdata, flags, reason_code, properties):
        if reason_code == 0:
            print(f"✅ Connected successfully to MQTT broker at {self.broker_host}:{self.broker_port}")
            self.connected = True
        else:
            print(f"❌ Failed to connect, return code {reason_code}")
            self.connected = False
            
    def on_connect_fail(self, client, userdata):
        print(f"❌ Connection failed to {self.broker_host}:{self.broker_port}")
        self.connected = False
            
    def on_publish(self, client, userdata, mid, reason_code, properties):
        print(f"📤 Message {mid} published successfully")
        
    def on_disconnect(self, client, userdata, flags, reason_code, properties):
        print("🔌 Disconnected from MQTT broker")
        self.connected = False
    
    def connect(self):
        """Connect to MQTT broker with proper error handling"""
        print(f"🔄 Attempting to connect to {self.broker_host}:{self.broker_port}...")
        
        try:
            # Test basic connectivity first
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((self.broker_host, self.broker_port))
            sock.close()
            
            if result != 0:
                print(f"❌ Cannot reach {self.broker_host}:{self.broker_port} - Port not accessible")
                return False
            
            print(f"✅ Port {self.broker_port} is reachable")
            
            # Now try MQTT connection
            self.client.connect(self.broker_host, self.broker_port, 60)
            self.client.loop_start()
            
            # Wait for connection with timeout
            timeout = 10
            start_time = time.time()
            
            while not self.connected and (time.time() - start_time) < timeout:
                time.sleep(0.1)
            
            if self.connected:
                print("✅ MQTT connection established")
                return True
            else:
                print("❌ MQTT connection timeout")
                self.client.loop_stop()
                return False
                
        except Exception as e:
            print(f"❌ Error connecting to broker: {e}")
            return False
    
    def disconnect(self):
        """Properly disconnect from broker"""
        if self.connected:
            self.client.loop_stop()
            self.client.disconnect()
            self.connected = False
    
    
    def generate_sensor_data(self, device_id, sensor_type):
        """Generate realistic sensor data based on type"""
        base_data = {
            "device_id": device_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sensor_type": sensor_type,
            "location": {
                "latitude": fake.latitude(),
                "longitude": fake.longitude(),
                "city": fake.city()
            }
        }
        
        if sensor_type == "temperature":
            base_data.update({
                "temperature": round(random.uniform(15.0, 35.0), 2),
                "humidity": round(random.uniform(30.0, 80.0), 2),
                "unit": "°C"
            })
        
        elif sensor_type == "air_quality":
            base_data.update({
                "pm25": round(random.uniform(5.0, 150.0), 1),
                "pm10": round(random.uniform(10.0, 200.0), 1),
                "co2": random.randint(300, 2000),
                "aqi": random.randint(1, 500)
            })
        
        elif sensor_type == "motion":
            base_data.update({
                "motion_detected": random.choice([True, False]),
                "confidence": round(random.uniform(0.7, 1.0), 3),
                "battery_level": random.randint(10, 100)
            })
        
        elif sensor_type == "smart_meter":
            base_data.update({
                "power_consumption": round(random.uniform(0.5, 15.0), 3),
                "voltage": round(random.uniform(220.0, 240.0), 2),
                "current": round(random.uniform(0.1, 10.0), 3),
                "unit": "kWh"
            })
        
        elif sensor_type == "vehicle":
            base_data.update({
                "vehicle_id": fake.license_plate(),
                "speed": round(random.uniform(0, 120), 1),
                "fuel_level": round(random.uniform(10, 100), 1),
                "engine_temp": round(random.uniform(80, 105), 1),
                "mileage": random.randint(1000, 200000)
            })
        
        elif sensor_type == "weather":
            base_data.update({
                "temperature": round(random.uniform(-10, 40), 1),
                "pressure": round(random.uniform(980, 1030), 1),
                "wind_speed": round(random.uniform(0, 30), 1),
                "wind_direction": random.randint(0, 360),
                "precipitation": round(random.uniform(0, 50), 2)
            })
        
        return base_data
    
    def generate_user_event(self):
        """Generate user activity events"""
        events = ["login", "logout", "purchase", "page_view", "click", "search"]
        return {
            "user_id": fake.uuid4(),
            "session_id": fake.uuid4(),
            "event_type": random.choice(events),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "ip_address": fake.ipv4(),
            "user_agent": fake.user_agent(),
            "page": fake.uri_path(),
            "country": fake.country_code(),
            "device_type": random.choice(["mobile", "desktop", "tablet"])
        }
    
    def generate_financial_data(self):
        """Generate financial transaction data"""
        return {
            "transaction_id": fake.uuid4(),
            "account_id": fake.uuid4(),
            "amount": round(random.uniform(1.0, 10000.0), 2),
            "currency": random.choice(["USD", "EUR", "GBP", "JPY"]),
            "transaction_type": random.choice(["debit", "credit", "transfer"]),
            "merchant": fake.company(),
            "category": random.choice(["food", "transport", "shopping", "utilities", "entertainment"]),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "location": fake.city()
        }
    
    def publish_sensor_data(self, device_count=5, interval=1.0, duration=60):
        """Publish IoT sensor data"""
        print(f"Starting sensor data generation for {duration} seconds...")
        
        sensor_types = ["temperature", "air_quality", "motion", "smart_meter", "vehicle", "weather"]
        devices = [f"device_{i:03d}" for i in range(device_count)]
        
        self.running = True
        start_time = time.time()
        
        while self.running and (time.time() - start_time) < duration:
            for device_id in devices:
                sensor_type = random.choice(sensor_types)
                data = self.generate_sensor_data(device_id, sensor_type)
                topic = f"sensors/{sensor_type}/{device_id}"
                
                safe_data = decimal_to_float(data)
                self.client.publish(topic, json.dumps(safe_data), qos=1)
    
            time.sleep(interval)
        
        print("Sensor data generation completed")
    
    def publish_user_events(self, events_per_second=10, duration=60):
        """Publish user activity events"""
        print(f"Starting user event generation for {duration} seconds...")
        
        self.running = True
        start_time = time.time()
        
        while self.running and (time.time() - start_time) < duration:
            for _ in range(events_per_second):
                data = self.generate_user_event()
                topic = f"events/user/{data['event_type']}"
                
                self.client.publish(topic, json.dumps(data), qos=0)
            
            time.sleep(1.0)
        
        print("User event generation completed")
    
    def publish_financial_data(self, transactions_per_minute=100, duration=60):
        """Publish financial transaction data"""
        print(f"Starting financial data generation for {duration} seconds...")
        
        self.running = True
        start_time = time.time()
        
        while self.running and (time.time() - start_time) < duration:
            for _ in range(transactions_per_minute):
                data = self.generate_financial_data()
                topic = f"financial/transactions/{data['currency']}"
                
                self.client.publish(topic, json.dumps(data), qos=1)
            
            time.sleep(60.0 / transactions_per_minute)
        
        print("Financial data generation completed")

def main():
    parser = argparse.ArgumentParser(description='MQTT Synthetic Data Generator')
    parser.add_argument('--broker', default='127.0.0.1', help='MQTT broker host')
    parser.add_argument('--port', type=int, default=1883, help='MQTT broker port')
    parser.add_argument('--username', help='MQTT username')
    parser.add_argument('--password', help='MQTT password')
    parser.add_argument('--type', choices=['sensors', 'events', 'financial', 'all'], 
                       default='sensors', help='Type of data to generate')
    parser.add_argument('--duration', type=int, default=60, help='Duration in seconds')
    parser.add_argument('--devices', type=int, default=5, help='Number of devices for sensor data')
    
    args = parser.parse_args()
    
    # Create generator
    generator = MQTTDataGenerator(
        broker_host=args.broker,
        broker_port=args.port
    )
    
    if not generator.connect():
        return
    
    try:
        if args.type == 'sensors':
            generator.publish_sensor_data(device_count=args.devices, duration=args.duration)
        elif args.type == 'events':
            generator.publish_user_events(duration=args.duration)
        elif args.type == 'financial':
            generator.publish_financial_data(duration=args.duration)
        elif args.type == 'all':
            # Run all generators in parallel
            threads = [
                threading.Thread(target=generator.publish_sensor_data, 
                               kwargs={'device_count': args.devices, 'duration': args.duration}),
                threading.Thread(target=generator.publish_user_events, 
                               kwargs={'duration': args.duration}),
                threading.Thread(target=generator.publish_financial_data, 
                               kwargs={'duration': args.duration})
            ]
            
            for thread in threads:
                thread.start()
            
            for thread in threads:
                thread.join()
    
    except KeyboardInterrupt:
        print("\nStopping data generation...")
    
    finally:
        generator.disconnect()
        print(f"Total messages published: TODO")
def decimal_to_float(obj):
    if isinstance(obj, dict):
        return {k: decimal_to_float(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [decimal_to_float(v) for v in obj]
    elif isinstance(obj, Decimal):
        return float(obj)
    return obj
if __name__ == "__main__":
    main()