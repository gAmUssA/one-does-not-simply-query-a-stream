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

# Include Kafka Connect specific targets
include kafka-connect/kafka-connect.mk

# Include Kwack specific targets
include kwack/kwack.mk

# Set help as the default target
.DEFAULT_GOAL := help

.PHONY: help start stop init query clean setup

help: ## 📚 Show this help message
> @printf "$(BLUE)🛠  Flight Status Pipeline Commands:$(NC)\n"
> @grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sed 's/^[^:]*://' | sort | awk -F'## ' '{gsub(/^[ \t]+|[ \t]+$$/, "", $$1); printf "$(YELLOW)%-35s$(NC) %s\n", $$1, $$2}'

start: kc-start init ## 🚀 Start the complete pipeline
> @printf "$(GREEN)🎉 Complete pipeline started successfully!$(NC)\n"

stop: ## 🛑 Stop the pipeline
> @printf "$(RED)🛑 Stopping all services...$(NC)\n"
> docker compose down
> @printf "$(RED)💤 Services stopped$(NC)\n"

init: ## 📦 Initialize SQLite database
> @printf "$(BLUE)📦 Initializing SQLite database...$(NC)\n"
> @printf "$(BLUE)⏳ Waiting for SQLite container to be ready...$(NC)\n"
> @for i in $$(seq 1 30); do \
>   if docker ps | grep -q sqlite; then \
>     printf "$(GREEN)✅ SQLite container is running$(NC)\n"; \
>     docker exec sqlite sh /data/init-sqlite.sh; \
>     printf "$(GREEN)✅ Database initialized$(NC)\n"; \
>     exit 0; \
>   fi; \
>   printf "$(YELLOW)⏳ Waiting for SQLite container to start ($$i/30)...$(NC)\n"; \
>   sleep 1; \
> done; \
> printf "$(RED)❌ SQLite container failed to start within 30 seconds$(NC)\n"; \
> exit 1

configure: kc-configure ## 🔌 Configure Kafka Connect (alias for kc-configure)
> @printf "$(GREEN)✅ Configuration complete$(NC)\n"

query: kc-query ## 🔍 Query flight status (alias for kc-query)

clean: stop ## 🧹 Clean up (stop and remove volumes)
> @printf "$(RED)🧹 Cleaning up volumes...$(NC)\n"
> docker compose down -v
> @printf "$(GREEN)✨ Cleanup complete$(NC)\n"

setup: start init configure ## 🎯 Complete setup (start, init, configure)
> @printf "$(GREEN)🎉 Setup complete! Use 'make query' to view flight data$(NC)\n"
