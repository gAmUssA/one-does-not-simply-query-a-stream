#!/bin/bash

echo "Querying flight status database..."

# Run a simple count query directly
echo "Checking row count:"
docker exec sqlite sqlite3 /data/flights.db "SELECT COUNT(*) FROM flights;"

# Run the full query directly
echo "Querying flight data:"
docker exec sqlite sqlite3 /data/flights.db ".mode column" ".headers on" "SELECT flightNumber, airline, origin as departure_airport, destination as arrival_airport, datetime(scheduledDeparture/1000, 'unixepoch') as scheduled_departure, datetime(actualDeparture/1000, 'unixepoch') as actual_departure, status FROM flights ORDER BY scheduledDeparture ASC LIMIT 10;"
