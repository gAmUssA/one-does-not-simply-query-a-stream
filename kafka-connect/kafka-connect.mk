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
.PHONY: kc-bootstrap kc-configure kc-start kc-status

kc-bootstrap: ## 🔌 Bootstrap Confluent Cloud configuration for Kafka Connect
> @printf "$(GREEN)🚀 Bootstrapping Confluent Cloud configuration...$(NC)\n"
> ./$(BOOTSTRAP_SCRIPT)
> @printf "$(GREEN)✅ Kafka Connect bootstrap complete$(NC)\n"

kc-configure: ## 🔧 Configure Kafka Connect JDBC sink
> @printf "$(BLUE)🔌 Configuring Kafka Connect JDBC sink...$(NC)\n"
> @sleep 10  # Wait for Kafka Connect to be fully ready
> docker exec connect sh /etc/kafka/configure-jdbc-sink.sh
> @printf "$(GREEN)✅ Connector configured$(NC)\n"

kc-start: kc-bootstrap ## 🚀 Start Kafka Connect services with bootstrap
> @printf "$(GREEN)🚀 Starting Connect services...$(NC)\n"
> docker compose up -d --build
> @printf "$(GREEN)✨ Kafka Connect services started successfully!$(NC)\n"

kc-status: ## 📊 Check Kafka Connect status
> @printf "$(BLUE)📊 Checking Kafka Connect status...$(NC)\n"
> @if docker ps | grep -q connect; then \
>   printf "$(GREEN)✅ Kafka Connect container is running$(NC)\n"; \
>   docker exec connect curl -s http://localhost:8083/connectors 2>/dev/null | jq . || printf "$(YELLOW)⚠️  No connectors found or jq not available$(NC)\n"; \
> else \
>   printf "$(RED)❌ Kafka Connect container is not running$(NC)\n"; \
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
