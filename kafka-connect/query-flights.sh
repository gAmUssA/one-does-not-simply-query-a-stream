#!/bin/bash

# 🔍 Query Flight Status Database
# This script queries the SQLite database with the current table schema

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

printf "${BLUE}🔍 Querying flight status database...${NC}\n"

# Check if table exists
if ! docker exec sqlite sqlite3 /data/flights.db "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='flights';" | grep -q 1; then
    printf "${RED}❌ Flights table not found. Run 'make kc-configure' first.${NC}\n"
    exit 1
fi

# Run a simple count query
printf "${BLUE}📊 Checking row count:${NC}\n"
COUNT=$(docker exec sqlite sqlite3 /data/flights.db "SELECT COUNT(*) FROM flights;")
printf "${GREEN}✅ Total flights: ${COUNT}${NC}\n\n"

if [ "$COUNT" -eq 0 ]; then
    printf "${YELLOW}⚠️ No flight data found. The connector may still be processing data.${NC}\n"
    exit 0
fi

# Run the full query with correct field names
printf "${BLUE}🛫 Flight data (using current schema):${NC}\n"
docker exec sqlite sqlite3 /data/flights.db ".mode column" ".headers on" "SELECT flight_number, airline, departure_airport, arrival_airport, scheduled_departure_time, actual_departure_time, status FROM flights ORDER BY scheduled_departure_time ASC LIMIT 10;"

printf "\n${BLUE}💡 Available query commands:${NC}\n"
printf "${YELLOW}  make kc-query         ${NC} - Basic flight overview\n"
printf "${YELLOW}  make kc-query-count   ${NC} - Data statistics\n"
printf "${YELLOW}  make kc-query-recent  ${NC} - Most recent flights\n"
printf "${YELLOW}  make kc-query-status  ${NC} - Flights by status\n"
printf "${YELLOW}  make kc-query-airlines${NC} - Flights by airline\n"
printf "${YELLOW}  make kc-query-delayed ${NC} - Delayed flights analysis\n"
