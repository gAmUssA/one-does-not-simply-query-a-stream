#!/bin/bash

# Script to validate .env file for Kafka Connect configuration

echo "Validating .env file for Kafka Connect configuration..."

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found in project root directory"
    exit 1
fi

# Extract and validate required values from .env
BOOTSTRAP_SERVERS=$(grep "BOOTSTRAP_SERVERS" .env | cut -d'=' -f2)
SCHEMA_REGISTRY_URL=$(grep "SCHEMA_REGISTRY_URL" .env | cut -d'=' -f2)
SCHEMA_REGISTRY_API_KEY=$(grep "SCHEMA_REGISTRY_API_KEY" .env | cut -d'=' -f2)
SCHEMA_REGISTRY_API_SECRET=$(grep "SCHEMA_REGISTRY_API_SECRET" .env | cut -d'=' -f2)
SASL_JAAS_CONFIG=$(grep "SASL_JAAS_CONFIG" .env | cut -d'=' -f2-)
TOPIC_NAME=$(grep "TOPIC_NAME" .env | cut -d'=' -f2)

# Validate required values
if [ -z "$BOOTSTRAP_SERVERS" ]; then
    echo "Error: BOOTSTRAP_SERVERS not found in .env file"
    exit 1
fi

if [ -z "$SCHEMA_REGISTRY_URL" ]; then
    echo "Error: SCHEMA_REGISTRY_URL not found in .env file"
    exit 1
fi

if [ -z "$SCHEMA_REGISTRY_API_KEY" ] || [ -z "$SCHEMA_REGISTRY_API_SECRET" ]; then
    echo "Error: Schema Registry credentials not found in .env file"
    exit 1
fi

if [ -z "$SASL_JAAS_CONFIG" ]; then
    echo "Error: SASL_JAAS_CONFIG not found in .env file"
    exit 1
fi

echo "✅ .env file validated successfully"
echo "📊 Configuration summary:"
echo "🔌 Bootstrap servers: $BOOTSTRAP_SERVERS"
echo "🔐 Schema Registry URL: $SCHEMA_REGISTRY_URL"
echo "📝 Topic name: ${TOPIC_NAME:-flights}"

echo "✨ Kafka Connect configuration validated successfully"