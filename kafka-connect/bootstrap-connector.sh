#!/bin/bash

# Script to bootstrap Kafka Connect configuration from cloud.properties

echo "Bootstrapping Kafka Connect configuration from cloud.properties..."

# Check if cloud.properties exists
if [ ! -f "kafka-connect/cloud.properties" ]; then
    echo "Error: cloud.properties file not found in kafka-connect directory"
    exit 1
fi

# Extract values from cloud.properties
BOOTSTRAP_SERVERS=$(grep "bootstrap.servers" kafka-connect/cloud.properties | cut -d'=' -f2)
SCHEMA_REGISTRY_URL=$(grep "schema.registry.url" kafka-connect/cloud.properties | cut -d'=' -f2)
SCHEMA_REGISTRY_API_INFO=$(grep "schema.registry.basic.auth.user.info" kafka-connect/cloud.properties | cut -d'=' -f2)
SASL_JAAS_CONFIG=$(grep "sasl.jaas.config" kafka-connect/cloud.properties | cut -d'=' -f2-)
TOPIC_NAME=$(grep "topic.name" kafka-connect/cloud.properties | cut -d'=' -f2)

# Split schema registry API info into key and secret
IFS=':' read -r SCHEMA_REGISTRY_API_KEY SCHEMA_REGISTRY_API_SECRET <<< "$SCHEMA_REGISTRY_API_INFO"

# Create .env file for docker-compose
cat > .env << EOF
BOOTSTRAP_SERVERS=$BOOTSTRAP_SERVERS
SCHEMA_REGISTRY_URL=$SCHEMA_REGISTRY_URL
SCHEMA_REGISTRY_API_KEY=$SCHEMA_REGISTRY_API_KEY
SCHEMA_REGISTRY_API_SECRET=$SCHEMA_REGISTRY_API_SECRET
SASL_JAAS_CONFIG=$SASL_JAAS_CONFIG
TOPIC_NAME=$TOPIC_NAME
EOF

echo "Environment variables set in .env file"
echo "Bootstrap servers: $BOOTSTRAP_SERVERS"
echo "Schema Registry URL: $SCHEMA_REGISTRY_URL"
echo "Topic name: $TOPIC_NAME"

echo "Kafka Connect configuration bootstrapped successfully"