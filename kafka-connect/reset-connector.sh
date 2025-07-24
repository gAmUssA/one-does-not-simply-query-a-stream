#!/bin/bash

# Reset Kafka Connect JDBC Sink Connector Offsets
# This script uses native Kafka Connect 3.6.0+ offset reset functionality
# https://cwiki.apache.org/confluence/display/KAFKA/KIP-875%3A+First-class+offsets+support+in+Kafka+Connect

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Determine script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Source environment variables from .env file
ENV_FILE="$PROJECT_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
    # Extract topic name from .env file
    TOPIC_NAME=$(grep "TOPIC_NAME" "$ENV_FILE" | cut -d'=' -f2)
    SCHEMA_REGISTRY_URL=$(grep "SCHEMA_REGISTRY_URL" "$ENV_FILE" | cut -d'=' -f2)
    SCHEMA_REGISTRY_API_KEY=$(grep "SCHEMA_REGISTRY_API_KEY" "$ENV_FILE" | cut -d'=' -f2)
    SCHEMA_REGISTRY_API_SECRET=$(grep "SCHEMA_REGISTRY_API_SECRET" "$ENV_FILE" | cut -d'=' -f2)
    printf "${BLUE}🔍 Using topic: ${TOPIC_NAME} from ${ENV_FILE}${NC}\n"
else
    # Default topic name if .env not found
    TOPIC_NAME="flights"
    printf "${YELLOW}⚠️ .env file not found at ${ENV_FILE}, using default topic: ${TOPIC_NAME}${NC}\n"
fi

# Connector name
CONNECTOR_NAME="jdbc_sink_connector"

# Check if Kafka Connect is running
printf "${BLUE}🔌 Checking if Kafka Connect is running...${NC}\n"
if ! curl -s http://localhost:8083 > /dev/null; then
    printf "${RED}❌ Kafka Connect is not running. Please start it first with 'make kc-start'${NC}\n"
    exit 1
fi

# Check if connector exists
printf "${BLUE}🔍 Checking if connector exists...${NC}\n"
if curl -s http://localhost:8083/connectors/${CONNECTOR_NAME} > /dev/null; then
    # Stop the connector (Kafka Connect 3.6.0+ native support)
    printf "${YELLOW}⏸️ Stopping connector...${NC}\n"
    curl -s -X PUT http://localhost:8083/connectors/${CONNECTOR_NAME}/stop
    
    # Wait for connector to stop
    printf "${YELLOW}⏳ Waiting for connector to stop...${NC}\n"
    while true; do
        STATUS=$(curl -s http://localhost:8083/connectors/${CONNECTOR_NAME}/status | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
        if [ "$STATUS" = "STOPPED" ]; then
            break
        fi
        printf "${YELLOW}.${NC}"
        sleep 1
    done
    printf "${GREEN}\n✅ Connector stopped${NC}\n"
    
    # Drop the flights table from SQLite database
    printf "${BLUE}🗑️ Dropping flights table from SQLite database...${NC}\n"
    docker exec sqlite sqlite3 /data/flights.db "DROP TABLE IF EXISTS flights;"
    printf "${GREEN}✅ Flights table dropped${NC}\n"
    
    # Reset connector offsets (Kafka Connect 3.6.0+ native support)
    printf "${BLUE}🔄 Resetting connector offsets...${NC}\n"
    RESET_RESPONSE=$(curl -s -X DELETE http://localhost:8083/connectors/${CONNECTOR_NAME}/offsets)
    if echo "$RESET_RESPONSE" | grep -q "error"; then
        printf "${RED}❌ Failed to reset offsets: ${RESET_RESPONSE}${NC}\n"
        exit 1
    fi
    printf "${GREEN}✅ Connector offsets reset${NC}\n"
    
    # Resume the connector
    printf "${BLUE}▶️ Resuming connector...${NC}\n"
    curl -s -X PUT http://localhost:8083/connectors/${CONNECTOR_NAME}/resume
    printf "${GREEN}✅ Connector resumed${NC}\n"
else
    printf "${YELLOW}⚠️ Connector does not exist, will create new one${NC}\n"
    # Run the configuration script to create the connector
    CONFIGURE_SCRIPT="$SCRIPT_DIR/configure-jdbc-sink.sh"
    if [ -f "$CONFIGURE_SCRIPT" ]; then
        printf "${BLUE}🔧 Creating new connector...${NC}\n"
        bash "$CONFIGURE_SCRIPT"
    else
        printf "${RED}❌ Connector configuration script not found at ${CONFIGURE_SCRIPT}${NC}\n"
        exit 1
    fi
fi

# Check connector status with retry logic
printf "${BLUE}🔍 Checking connector status...${NC}\n"
RETRY_COUNT=0
MAX_RETRIES=10

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    CONNECTOR_STATUS=$(curl -s http://localhost:8083/connectors/${CONNECTOR_NAME}/status)
    if echo "$CONNECTOR_STATUS" | grep -q "RUNNING"; then
        printf "${GREEN}\n✅ Connector is running${NC}\n"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            printf "${YELLOW}.${NC}"
            sleep 2
        else
            printf "${RED}\n❌ Connector failed to start after ${MAX_RETRIES} attempts. Status: ${NC}\n"
            echo "$CONNECTOR_STATUS" | grep -o '"state":"[^"]*"'
            exit 1
        fi
    fi
done

printf "${BLUE}📊 To view data, run: make query${NC}\n"
printf "${GREEN}🎉 Connector offset reset complete${NC}\n"
