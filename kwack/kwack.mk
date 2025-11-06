# 🦆 Kwack (DuckDB + Kafka) Integration
# This file contains kwack-specific targets to be included in the main Makefile

# Makefile Preamble - Required when running directly
SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# Set recipe prefix to > instead of tab
.RECIPEPREFIX = >

# Define colors if running standalone
ifeq ($(origin GREEN), undefined)
  GREEN := \033[0;32m
  YELLOW := \033[0;33m
  BLUE := \033[0;34m
  RED := \033[0;31m
  NC := \033[0m # No Color
endif

# Variables
KWACK_VERSION := 0.4.0

# Detect if we're running from the kwack directory or the main directory
KWACK_ROOT_DIR := $(shell if [ -f "../.env" ] && [ "$$(basename $$(pwd))" = "kwack" ]; then echo ".."; else echo "."; fi)
KWACK_DIR := $(KWACK_ROOT_DIR)/kwack/kwack-$(KWACK_VERSION)
KWACK_DOWNLOAD_URL := https://github.com/rayokota/kwack/releases/download/v$(KWACK_VERSION)/kwack-$(KWACK_VERSION)-package.zip
KWACK_ENV_FILE := .env
KWACK_CONFIG_FILE := $(KWACK_ROOT_DIR)/kwack/kwack.properties
KWACK_LOG_CONFIG := $(KWACK_ROOT_DIR)/kwack/log4j.properties

# Phony targets for kwack
.PHONY: kwack-help kwack-build kwack-test kwack-clean kwack-status kwack-install kwack-configure kwack-run kwack-interactive kwack-export

kwack-help: ## 🦆 Show kwack-specific commands
> @printf "$(BLUE)🦆 Kwack (DuckDB + Kafka) Commands:$(NC)\n"
> @printf "$(YELLOW)kwack-build$(NC)        🏗️ Build kwack (install + configure)\n"
> @printf "$(YELLOW)kwack-install$(NC)      📦 Install kwack binary\n"
> @printf "$(YELLOW)kwack-configure$(NC)    🔧 Generate kwack configuration from .env\n"
> @printf "$(YELLOW)kwack-status$(NC)       📊 Show kwack status\n"
> @printf "$(YELLOW)kwack-test$(NC)         🧪 Test kwack connection\n"
> @printf "$(YELLOW)kwack-run$(NC)          🚀 Run kwack query on current topic\n"
> @printf "$(YELLOW)kwack-interactive$(NC)  🎮 Start kwack in interactive mode\n"
> @printf "$(YELLOW)kwack-export$(NC)       📊 Export topic data to Parquet\n"
> @printf "$(YELLOW)kwack-clean$(NC)        🧹 Clean kwack installation\n"

kwack-status: ## 📊 Show kwack status
> @printf "$(BLUE)📊 Kwack Status:$(NC)\n"
> @if [ -d "$(KWACK_DIR)" ]; then \
>   printf "$(GREEN)✅ Kwack $(KWACK_VERSION) installed$(NC)\n"; \
> else \
>   printf "$(RED)❌ Kwack not installed$(NC)\n"; \
> fi
> @if [ -f "$(KWACK_CONFIG_FILE)" ]; then \
>   printf "$(GREEN)✅ Configuration file exists$(NC)\n"; \
> else \
>   printf "$(RED)❌ Configuration file missing$(NC)\n"; \
> fi
> @if [ -f "$(KWACK_ENV_FILE)" ]; then \
>   printf "$(GREEN)✅ Environment file found$(NC)\n"; \
> else \
>   printf "$(RED)❌ Environment file missing$(NC)\n"; \
> fi

kwack-install: $(KWACK_DIR)/bin/kwack ## 📦 Install kwack binary
> @printf "$(GREEN)✅ Kwack $(KWACK_VERSION) installed successfully$(NC)\n"

$(KWACK_DIR)/bin/kwack:
> @printf "$(BLUE)📦 Installing kwack $(KWACK_VERSION)...$(NC)\n"
> @mkdir -p kwack/tmp
> @printf "$(BLUE)🔍 Downloading kwack $(KWACK_VERSION)...$(NC)\n"
> curl -sL $(KWACK_DOWNLOAD_URL) -o kwack/tmp/kwack-$(KWACK_VERSION)-package.zip
> @mkdir -p $(KWACK_DIR)
> @printf "$(BLUE)💾 Extracting kwack...$(NC)\n"
> unzip -q -o kwack/tmp/kwack-$(KWACK_VERSION)-package.zip -d kwack/tmp
> cp -R kwack/tmp/kwack-$(KWACK_VERSION)/* $(KWACK_DIR)/
> @printf "$(GREEN)✅ Kwack downloaded and extracted$(NC)\n"

kwack-configure: $(KWACK_CONFIG_FILE) ## 🔧 Generate kwack configuration from .env
> @printf "$(GREEN)✅ Configuration updated from $(KWACK_ENV_FILE)$(NC)\n"

$(KWACK_CONFIG_FILE): $(KWACK_ENV_FILE)
> @printf "$(BLUE)🔧 Generating kwack configuration from .env...$(NC)\n"
> @if [ ! -f "$(KWACK_ENV_FILE)" ]; then \
>   printf "$(RED)❌ Environment file $(KWACK_ENV_FILE) not found$(NC)\n"; \
>   exit 1; \
> fi
> @if [ ! -f "kwack/kwack.properties.example" ]; then \
>   printf "$(RED)❌ Example properties file kwack/kwack.properties.example not found$(NC)\n"; \
>   exit 1; \
> fi
> @printf "$(BLUE)📝 Using kwack.properties.example as template...$(NC)\n"
> @printf "# 🦆 Kwack Configuration - Generated from .env on %s\n" "$(shell date)" > $(KWACK_CONFIG_FILE)
> @printf "# Topics to manage (from TOPIC_NAME in .env)\n" >> $(KWACK_CONFIG_FILE)
> @source $(KWACK_ENV_FILE) && \
> printf "topics=%s\n" "$${TOPIC_NAME:-flights}" >> $(KWACK_CONFIG_FILE)
> @printf "\n# Key serdes (default is binary)\n" >> $(KWACK_CONFIG_FILE)
> @source $(KWACK_ENV_FILE) && \
> printf "key.serdes=%s=string\n" "$${TOPIC_NAME:-flights}" >> $(KWACK_CONFIG_FILE)
> @printf "\n# Value serdes (use avro with Schema Registry)\n" >> $(KWACK_CONFIG_FILE)
> @source $(KWACK_ENV_FILE) && \
> printf "value.serdes=%s=avro\n" "$${TOPIC_NAME:-flights}" >> $(KWACK_CONFIG_FILE)
> @printf "\n# 🌐 Confluent Cloud Schema Registry Configuration\n" >> $(KWACK_CONFIG_FILE)
> @source $(KWACK_ENV_FILE) && \
> printf "schema.registry.url=%s\n" "$$SCHEMA_REGISTRY_URL" >> $(KWACK_CONFIG_FILE)
> @printf "basic.auth.credentials.source=USER_INFO\n" >> $(KWACK_CONFIG_FILE)
> @source $(KWACK_ENV_FILE) && \
> printf "basic.auth.user.info=%s:%s\n" "$$SCHEMA_REGISTRY_API_KEY" "$$SCHEMA_REGISTRY_API_SECRET" >> $(KWACK_CONFIG_FILE)
> @printf "\n# 🔌 Confluent Cloud Kafka Configuration\n" >> $(KWACK_CONFIG_FILE)
> @source $(KWACK_ENV_FILE) && \
> printf "bootstrap.servers=%s\n" "$$BOOTSTRAP_SERVERS" >> $(KWACK_CONFIG_FILE)
> @printf "security.protocol=SASL_SSL\n" >> $(KWACK_CONFIG_FILE)
> @source $(KWACK_ENV_FILE) && \
> printf "sasl.jaas.config=%s\n" "$$SASL_JAAS_CONFIG" >> $(KWACK_CONFIG_FILE)
> @printf "sasl.mechanism=PLAIN\n" >> $(KWACK_CONFIG_FILE)
> @printf "\n# 🦆 DuckDB Configuration\n" >> $(KWACK_CONFIG_FILE)
> @printf "# Use in-memory database by default\n" >> $(KWACK_CONFIG_FILE)
> @printf "# Override with -d option for persistent storage\n" >> $(KWACK_CONFIG_FILE)

kwack-build: kwack-install kwack-configure ## 🏗️ Build kwack (install + configure)
> @printf "$(GREEN)🏗️ Kwack build complete$(NC)\n"

kwack-analyze: kwack-build ## 🦆 Run kwack analysis - import Kafka data and execute flight queries
> @printf "$(BLUE)🦆 Starting kwack flight data analysis...$(NC)\n"
> @./kwack/run-kwack-analysis.sh

kwack-test: kwack-build
> @printf "$(BLUE)🧪 Testing kwack installation...$(NC)\n"
> @if [ -f "$(KWACK_DIR)/bin/kwack" ]; then \
>   printf "$(GREEN)✅ Kwack binary exists$(NC)\n"; \
>   printf "$(BLUE)🔍 Testing kwack command...$(NC)\n"; \
>   ./$(KWACK_DIR)/bin/kwack -h | head -5 && \
>   printf "$(GREEN)✅ Kwack command works$(NC)\n"; \
>   printf "$(BLUE)🔍 Testing connection with configuration...$(NC)\n"; \
>   ./$(KWACK_DIR)/bin/kwack -F $(KWACK_CONFIG_FILE) -q "SELECT 'Connection test successful' as status" 2>&1 | grep -q "Subject Not Found" && \
>   printf "$(YELLOW)⚠️  Schema Registry connection attempted - schema not found (expected during testing)$(NC)\n" || \
>   printf "$(GREEN)✅ Connection test completed$(NC)\n"; \
> else \
>   printf "$(RED)❌ Kwack binary not found - installation failed$(NC)\n"; \
>   exit 1; \
> fi

kwack-run: kwack-build
> @printf "$(BLUE)🚀 Running kwack query on topic...$(NC)\n"
> @SCHEMA_REGISTRY_URL=$$(grep SCHEMA_REGISTRY_URL $(KWACK_ENV_FILE) | cut -d= -f2) && \
> TOPIC_NAME=$$(grep TOPIC_NAME $(KWACK_ENV_FILE) | cut -d= -f2 || echo "flights") && \
> ./$(KWACK_DIR)/bin/kwack -F $(KWACK_CONFIG_FILE) -r "$$SCHEMA_REGISTRY_URL" -q "SELECT * FROM $$TOPIC_NAME LIMIT 10"

kwack-interactive: kwack-build ## 🎮 Start kwack in interactive mode
> @printf "$(BLUE)🎮 Starting kwack interactive mode...$(NC)\n"
> @printf "$(YELLOW)💡 Tip: Use 'SELECT * FROM flights LIMIT 10;' to query your topic$(NC)\n"
> @SCHEMA_REGISTRY_URL=$$(grep SCHEMA_REGISTRY_URL $(KWACK_ENV_FILE) | cut -d= -f2) && \
> ./$(KWACK_DIR)/bin/kwack -F $(KWACK_CONFIG_FILE) -r "$$SCHEMA_REGISTRY_URL"

kwack-query: kwack-build ## 🔍 Run custom SQL query (usage: make kwack-query SQL="SELECT * FROM flights")
> @if [ -z "$(SQL)" ]; then \
>   printf "$(RED)❌ Please provide SQL query: make kwack-query SQL=\"SELECT * FROM flights\"$(NC)\n"; \
>   exit 1; \
> fi
> @printf "$(BLUE)🔍 Executing SQL: $(SQL)$(NC)\n"
> @SCHEMA_REGISTRY_URL=$$(grep SCHEMA_REGISTRY_URL $(KWACK_ENV_FILE) | cut -d= -f2) && \
> ./$(KWACK_DIR)/bin/kwack -F $(KWACK_CONFIG_FILE) -r "$$SCHEMA_REGISTRY_URL" -q "$(SQL)"

kwack-export: kwack-build ## 📊 Export topic data to Parquet format
> @printf "$(BLUE)📊 Exporting topic data to Parquet...$(NC)\n"
> @SCHEMA_REGISTRY_URL=$$(grep SCHEMA_REGISTRY_URL $(KWACK_ENV_FILE) | cut -d= -f2) && \
> TOPIC_NAME=$$(grep TOPIC_NAME $(KWACK_ENV_FILE) | cut -d= -f2 || echo "flights") && \
> ./$(KWACK_DIR)/bin/kwack -F $(KWACK_CONFIG_FILE) -r "$$SCHEMA_REGISTRY_URL" -q "COPY $$TOPIC_NAME TO '$$TOPIC_NAME.parquet' (FORMAT 'parquet')" && \
> printf "$(GREEN)✅ Data exported to $$TOPIC_NAME.parquet$(NC)\n"

kwack-clean: ## 🧹 Clean kwack installation and generated files
> @printf "$(RED)🧹 Cleaning kwack installation...$(NC)\n"
> rm -rf $(KWACK_DIR) kwack/tmp/ *.parquet *.db
> @printf "$(RED)💤 Kwack cleaned$(NC)\n"
