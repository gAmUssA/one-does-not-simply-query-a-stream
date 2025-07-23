#!/bin/bash

# Source environment variables from .env file if it exists
if [ -f "/etc/kafka/cloud.properties" ]; then
    # Extract values directly from cloud.properties
    SCHEMA_REGISTRY_URL=$(grep "schema.registry.url" /etc/kafka/cloud.properties | cut -d'=' -f2)
    SCHEMA_REGISTRY_API_INFO=$(grep "schema.registry.basic.auth.user.info" /etc/kafka/cloud.properties | cut -d'=' -f2)
    TOPIC_NAME=$(grep "topic.name" /etc/kafka/cloud.properties | cut -d'=' -f2)

    # Split schema registry API info into key and secret
    IFS=':' read -r SCHEMA_REGISTRY_API_KEY SCHEMA_REGISTRY_API_SECRET <<< "$SCHEMA_REGISTRY_API_INFO"
fi

# Wait for Kafka Connect to be ready
while ! curl -s -f http://localhost:8083/connectors > /dev/null; do
    echo "Waiting for Kafka Connect to be ready..."
    sleep 1
done

echo "Configuring JDBC Sink Connector..."

# Get topic name from environment variable or use default
TOPIC=${TOPIC_NAME:-flights}

# Create a temporary file for the JSON payload
cat > /tmp/connector-config.json << EOF
{
  "name": "jdbc_sink_connector",
  "config": {
    "name": "jdbc_sink_connector",
    "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
    "tasks.max": "1",
    "topics": "$TOPIC",
    "connection.url": "jdbc:sqlite:/data/flights.db",
    "auto.create": "true",
    "auto.evolve": "true",
    "insert.mode": "upsert",
    "pk.mode": "record_value",
    "pk.fields": "flightNumber",
    "transforms": "TimestampConverter,RenameFields",
    "transforms.TimestampConverter.type": "org.apache.kafka.connect.transforms.TimestampConverter\$Value",
    "transforms.TimestampConverter.field": "scheduledDeparture",
    "transforms.TimestampConverter.target.type": "string",
    "transforms.TimestampConverter.format": "yyyy-MM-dd HH:mm:ss",
    "transforms.RenameFields.type": "org.apache.kafka.connect.transforms.ReplaceField\$Value",
    "transforms.RenameFields.renames": "{\"flightNumber\":\"flight_number\",\"airline\":\"airline\",\"origin\":\"departure_airport\",\"destination\":\"arrival_airport\",\"scheduledDeparture\":\"scheduled_departure_time\",\"actualDeparture\":\"actual_departure_time\",\"status\":\"status\"}",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "${SCHEMA_REGISTRY_URL}",
    "value.converter.basic.auth.credentials.source": "USER_INFO",
    "value.converter.schema.registry.basic.auth.user.info": "${SCHEMA_REGISTRY_API_KEY}:${SCHEMA_REGISTRY_API_SECRET}"
  }
}
EOF

# Send the JSON payload to the Kafka Connect REST API
curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" -d @/tmp/connector-config.json

# Clean up the temporary file
rm /tmp/connector-config.json

echo "JDBC Sink Connector configuration completed."
