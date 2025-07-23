#!/bin/bash

echo "Initializing SQLite database..."

# Create SQLite database and table
cat > /data/init.sql << 'EOF'
CREATE TABLE IF NOT EXISTS flight_status (
    flight_number TEXT PRIMARY KEY,
    airline TEXT,
    departure_airport TEXT,
    arrival_airport TEXT,
    scheduled_departure TEXT,
    actual_departure TEXT,
    status TEXT,
    event_timestamp BIGINT
);
EOF

sqlite3 /data/flights.db < /data/init.sql

echo "SQLite database initialized successfully."
