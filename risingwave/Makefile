# 🌊 RisingWave with Confluent Cloud Integration
# GNU Make 4.0+ required for .RECIPEPREFIX support
ifeq ($(origin .RECIPEPREFIX), undefined)
$(error This Make does not support .RECIPEPREFIX. Please use GNU Make 4.0 or later)
endif

# Makefile Preamble - Davis-Hansson Best Practices
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
NC := \033[0m

# Default target
.DEFAULT_GOAL := help

.PHONY: help start create info destroy run-client status check-env

help: ## 📚 Show this help message
> @printf "$(BLUE)🌊 RisingWave with Confluent Cloud$(NC)\n"
> @printf "$(YELLOW)Available targets:$(NC)\n"
> @awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check-env: ## 🔍 Check if .env file exists and has required variables
> @if [ ! -f "../.env" ]; then \
>   printf "$(RED)❌ .env file not found in parent directory$(NC)\n"; \
>   printf "$(YELLOW)💡 Copy .env.example to .env and configure your Confluent Cloud settings$(NC)\n"; \
>   exit 1; \
> fi
> @printf "$(GREEN)✅ .env file found$(NC)\n"
> @if ! grep -q "BOOTSTRAP_SERVERS" ../.env; then \
>   printf "$(RED)❌ BOOTSTRAP_SERVERS not found in .env$(NC)\n"; \
>   exit 1; \
> fi
> @printf "$(GREEN)✅ Confluent Cloud configuration detected$(NC)\n"

start: check-env ## 🚀 Start RisingWave with Confluent Cloud connection
> @printf "$(BLUE)🌊 Starting RisingWave with Confluent Cloud integration...$(NC)\n"
> docker compose up -d
> @printf "$(YELLOW)⏳ Waiting for RisingWave to be ready...$(NC)\n"
> @while ! nc -z localhost 4566; do \
>   sleep 1; \
>   printf "."; \
> done
> @printf "\n$(GREEN)✅ 🌊 RisingWave is ready!$(NC)\n"

create: start ## 🏗️ Alias for start (backward compatibility)

info: ## 📊 Show connection information
> @printf "\n$(BLUE)===========================================================$(NC)\n"
> @printf "$(GREEN)🌊 RisingWave Connection Info:$(NC)\n"
> @printf "$(BLUE)===========================================================$(NC)\n"
> @printf "🔗 RisingWave Frontend: $(YELLOW)localhost:4566$(NC)\n"
> @printf "📊 RisingWave Metrics:  $(YELLOW)localhost:5691$(NC)\n"
> @printf "☁️  Confluent Cloud:     $(YELLOW)Connected via .env$(NC)\n"
> @printf "$(BLUE)===========================================================$(NC)\n"
> @printf "$(GREEN)💡 Connect with: docker compose exec -it psql-client psql -h risingwave -p 4566 -d dev -U root$(NC)\n"
> @printf "$(BLUE)===========================================================$(NC)\n"

status: ## 📈 Check RisingWave status
> @printf "$(BLUE)📊 RisingWave Status:$(NC)\n"
> @if docker compose ps risingwave | grep -q "Up"; then \
>   printf "$(GREEN)✅ RisingWave is running$(NC)\n"; \
> else \
>   printf "$(RED)❌ RisingWave is not running$(NC)\n"; \
> fi
> @if nc -z localhost 4566; then \
>   printf "$(GREEN)✅ RisingWave frontend is accessible$(NC)\n"; \
> else \
>   printf "$(RED)❌ RisingWave frontend is not accessible$(NC)\n"; \
> fi

destroy: ## 🧹 Stop and remove all containers
> @printf "$(RED)🧹 Stopping and removing RisingWave containers...$(NC)\n"
> docker compose down -v
> @printf "$(GREEN)✅ Cleanup complete$(NC)\n"

run-client: ## 🔌 Connect to RisingWave using psql client
> @printf "$(BLUE)🔌 Connecting to RisingWave...$(NC)\n"
> docker compose exec -it psql-client psql -h risingwave -p 4566 -d dev -U root

logs: ## 📝 Show RisingWave logs
> @printf "$(BLUE)📝 RisingWave logs:$(NC)\n"
> docker compose logs -f risingwave