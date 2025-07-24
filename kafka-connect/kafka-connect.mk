# 🔌 Kafka Connect Makefile Include
# This file contains all Kafka Connect related targets and recipes

# GNU Make 4.0+ version check
ifeq ($(origin .RECIPEPREFIX), undefined)
$(error This Make does not support .RECIPEPREFIX. Please use GNU Make 4.0 or later)
endif

# Makefile Preamble
SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
.RECIPEPREFIX = >

# ANSI color codes
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
RED := \033[0;31m
NC := \033[0m # No Color

# Kafka Connect specific variables
KAFKA_CONNECT_DIR := kafka-connect
BOOTSTRAP_SCRIPT := $(KAFKA_CONNECT_DIR)/bootstrap-connector.sh
CONFIGURE_SCRIPT := $(KAFKA_CONNECT_DIR)/configure-jdbc-sink.sh

# Kafka Connect targets
.PHONY: kc-bootstrap kc-configure kc-start kc-status kc-reset

kc-bootstrap: ## 🔌 Bootstrap Confluent Cloud configuration for Kafka Connect
> @printf "$(GREEN)🚀 Bootstrapping Confluent Cloud configuration...$(NC)\n"
> ./$(BOOTSTRAP_SCRIPT)
> @printf "$(GREEN)✅ Kafka Connect bootstrap complete$(NC)\n"

kc-configure: ## 🔧 Configure Kafka Connect JDBC sink
> @printf "$(BLUE)🔌 Configuring Kafka Connect JDBC sink...$(NC)\n"
> @printf "$(YELLOW)⏳ Waiting for Kafka Connect to be ready...$(NC)\n"
> @while ! curl -s -f http://localhost:8083/connectors > /dev/null; do \
>   printf "$(YELLOW).$(NC)"; \
>   sleep 1; \
> done
> @printf "$(GREEN)\n✅ Kafka Connect is ready!$(NC)\n"
> docker exec connect sh /etc/kafka/configure-jdbc-sink.sh
> @printf "$(GREEN)✅ Connector configured$(NC)\n"

kc-start: kc-bootstrap ## 🚀 Start Kafka Connect services with bootstrap
> @printf "$(GREEN)🚀 Starting Connect services...$(NC)\n"
> COMPOSE_BAKE=true docker compose up -d --build
> @printf "$(GREEN)✨ Kafka Connect services started successfully!$(NC)\n"

kc-status: ## 📊 Check Kafka Connect status
> @printf "$(BLUE)📊 Checking Kafka Connect status...$(NC)\n"
> @if curl -s http://localhost:8083 > /dev/null 2>&1; then \
>   printf "$(GREEN)✅ Kafka Connect service is running$(NC)\n"; \
>   printf "$(BLUE)📋 Connectors:$(NC)\n"; \
>   curl -s http://localhost:8083/connectors 2>/dev/null | jq . || printf "$(YELLOW)⚠️  No connectors found or jq not available$(NC)\n"; \
> else \
>   printf "$(RED)❌ Kafka Connect service is not running$(NC)\n"; \
> fi

kc-logs: ## 📋 Show Kafka Connect logs
> @printf "$(BLUE)📋 Showing Kafka Connect logs...$(NC)\n"
> docker logs connect --tail=50 -f

kc-clean: ## 🧹 Clean Kafka Connect specific resources
> @printf "$(YELLOW)🧹 Cleaning Kafka Connect resources...$(NC)\n"
> @if docker ps -q -f name=connect | grep -q .; then \
>   docker stop connect; \
>   printf "$(GREEN)✅ Kafka Connect container stopped$(NC)\n"; \
> else \
>   printf "$(BLUE)ℹ️  Kafka Connect container not running$(NC)\n"; \
> fi

kc-reset: ## 🔄 Reset Kafka Connect connector offsets to process from beginning
> @printf "$(BLUE)🔄 Resetting Kafka Connect connector offsets...$(NC)\n"
> ./$(KAFKA_CONNECT_DIR)/reset-connector.sh
> @printf "$(GREEN)✅ Connector offsets reset complete$(NC)\n"

# Query targets
.PHONY: kc-query kc-query-count kc-query-recent kc-query-status kc-query-airlines kc-query-delayed

kc-query: ## 🔍 Query flight status data (basic overview)
> @printf "$(BLUE)🔍 Querying flight status data...$(NC)\n"
> @printf "$(YELLOW)⏳ Checking if data is available...$(NC)\n"
> @for i in $$(seq 1 5); do \
>   if docker exec sqlite sqlite3 /data/flights.db "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='flights';" | grep -q 1; then \
>     printf "$(GREEN)✅ Table found, querying data...$(NC)\n"; \
>     docker exec sqlite sqlite3 /data/flights.db \
>       ".mode column" \
>       ".headers on" \
>       "SELECT flight_number, airline, departure_airport, arrival_airport, scheduled_departure_time, actual_departure_time, status FROM flights ORDER BY scheduled_departure_time ASC LIMIT 10;"; \
>     exit 0; \
>   fi; \
>   printf "$(YELLOW)⏳ Waiting for table to be created ($$i/5)...$(NC)\n"; \
>   sleep 2; \
> done; \
> printf "$(RED)❌ Table not found within timeout period. Run 'make kc-configure' and try again.$(NC)\n"; \
> exit 1

kc-query-count: ## 📊 Show flight data count and table info
> @printf "$(BLUE)📊 Flight data statistics...$(NC)\n"
> @if docker exec sqlite sqlite3 /data/flights.db "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='flights';" | grep -q 1; then \
>   printf "$(GREEN)📈 Total flights: $(NC)"; \
>   docker exec sqlite sqlite3 /data/flights.db "SELECT COUNT(*) FROM flights;"; \
>   printf "$(BLUE)📋 Table schema:$(NC)\n"; \
>   docker exec sqlite sqlite3 /data/flights.db ".schema flights"; \
> else \
>   printf "$(RED)❌ Flights table not found$(NC)\n"; \
> fi

kc-query-recent: ## 🕐 Show most recent flight data
> @printf "$(BLUE)🕐 Most recent flight data...$(NC)\n"
> @if docker exec sqlite sqlite3 /data/flights.db "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='flights';" | grep -q 1; then \
>   docker exec sqlite sqlite3 /data/flights.db \
>     ".mode column" \
>     ".headers on" \
>     "SELECT flight_number, airline, departure_airport, arrival_airport, scheduled_departure_time, status FROM flights ORDER BY rowid DESC LIMIT 5;"; \
> else \
>   printf "$(RED)❌ Flights table not found$(NC)\n"; \
> fi

kc-query-status: ## 📋 Show flights grouped by status
> @printf "$(BLUE)📋 Flight status summary...$(NC)\n"
> @if docker exec sqlite sqlite3 /data/flights.db "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='flights';" | grep -q 1; then \
>   docker exec sqlite sqlite3 /data/flights.db \
>     ".mode column" \
>     ".headers on" \
>     "SELECT status, COUNT(*) as count FROM flights GROUP BY status ORDER BY count DESC;"; \
> else \
>   printf "$(RED)❌ Flights table not found$(NC)\n"; \
> fi

kc-query-airlines: ## ✈️ Show flights grouped by airline
> @printf "$(BLUE)✈️ Flights by airline...$(NC)\n"
> @if docker exec sqlite sqlite3 /data/flights.db "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='flights';" | grep -q 1; then \
>   docker exec sqlite sqlite3 /data/flights.db \
>     ".mode column" \
>     ".headers on" \
>     "SELECT airline, COUNT(*) as flight_count FROM flights GROUP BY airline ORDER BY flight_count DESC;"; \
> else \
>   printf "$(RED)❌ Flights table not found$(NC)\n"; \
> fi

kc-query-delayed: ## ⏰ Show delayed flights (where actual > scheduled)
> @printf "$(BLUE)⏰ Delayed flights analysis...$(NC)\n"
> @if docker exec sqlite sqlite3 /data/flights.db "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='flights';" | grep -q 1; then \
>   docker exec sqlite sqlite3 /data/flights.db \
>     ".mode column" \
>     ".headers on" \
>     "SELECT flight_number, airline, departure_airport, arrival_airport, scheduled_departure_time, actual_departure_time, status FROM flights WHERE actual_departure_time IS NOT NULL AND actual_departure_time > scheduled_departure_time ORDER BY scheduled_departure_time DESC LIMIT 10;"; \
> else \
>   printf "$(RED)❌ Flights table not found$(NC)\n"; \
> fi
