# TableFlow Demo Makefile
# Colorful output with emojis

# Colors
BOLD := $(shell tput bold)
GREEN := $(shell tput setaf 2)
YELLOW := $(shell tput setaf 3)
BLUE := $(shell tput setaf 4)
MAGENTA := $(shell tput setaf 5)
CYAN := $(shell tput setaf 6)
RESET := $(shell tput sgr0)

# Default target
.PHONY: help
help:
	@echo "$(BOLD)$(CYAN)🌊 TableFlow Demo with Trino and Superset 🌊$(RESET)"
	@echo "$(YELLOW)Available commands:$(RESET)"
	@echo "  $(BOLD)setup$(RESET)    - 🚀 Complete setup (copy example properties and start services)"
	@echo "  $(BOLD)start$(RESET)    - 🟢 Start the Trino and Superset containers"
	@echo "  $(BOLD)stop$(RESET)     - 🔴 Stop all containers"
	@echo "  $(BOLD)restart$(RESET)  - 🔄 Restart all containers"
	@echo "  $(BOLD)status$(RESET)   - 📊 Check the status of all containers"
	@echo "  $(BOLD)query$(RESET)    - 🔍 Run example queries against TableFlow tables"
	@echo "  $(BOLD)clean$(RESET)    - 🧹 Stop all containers and remove volumes"

# Setup target
.PHONY: setup
setup: copy-properties start
	@echo "$(BOLD)$(GREEN)✅ TableFlow setup complete!$(RESET)"
	@echo "$(CYAN)🔹 Trino UI: http://localhost:8080$(RESET)"
	@echo "$(CYAN)🔹 Superset UI: http://localhost:8088 (login with admin/admin)$(RESET)"

# Copy properties file if it doesn't exist
.PHONY: copy-properties
copy-properties:
	@if [ ! -f "trino/catalog/tableflow.properties" ]; then \
		echo "$(BOLD)$(YELLOW)📝 Creating tableflow.properties from example...$(RESET)"; \
		cp trino/catalog/tableflow.properties.example trino/catalog/tableflow.properties; \
		echo "$(BOLD)$(YELLOW)⚠️  Please edit trino/catalog/tableflow.properties with your credentials!$(RESET)"; \
	else \
		echo "$(BOLD)$(GREEN)✓ tableflow.properties already exists$(RESET)"; \
	fi

# Start containers
.PHONY: start
start:
	@echo "$(BOLD)$(GREEN)🚀 Starting TableFlow services...$(RESET)"
	docker compose up -d
	@echo "$(BOLD)$(GREEN)✅ Services started!$(RESET)"
	@echo "$(CYAN)🔹 Trino UI: http://localhost:8080$(RESET)"
	@echo "$(CYAN)🔹 Superset UI: http://localhost:8088 (login with admin/admin)$(RESET)"
	@echo "$(YELLOW)⏳ Please allow a few moments for services to fully initialize$(RESET)"

# Stop containers
.PHONY: stop
stop:
	@echo "$(BOLD)$(YELLOW)🛑 Stopping TableFlow services...$(RESET)"
	docker compose down
	@echo "$(BOLD)$(GREEN)✅ Services stopped!$(RESET)"

# Restart containers
.PHONY: restart
restart: stop start
	@echo "$(BOLD)$(GREEN)✅ Services restarted!$(RESET)"

# Check status
.PHONY: status
status:
	@echo "$(BOLD)$(BLUE)📊 Checking TableFlow services status...$(RESET)"
	docker compose ps
	@echo "$(BOLD)$(GREEN)✅ Status check complete!$(RESET)"

# Run example queries
.PHONY: query
query:
	@echo "$(BOLD)$(MAGENTA)🔍 Running example queries against TableFlow...$(RESET)"
	@echo "$(CYAN)Connecting to Trino...$(RESET)"
	@echo "$(YELLOW)Note: This requires the Trino CLI to be installed.$(RESET)"
	@echo "$(YELLOW)If not installed, run: docker exec -it trino trino --server localhost:8080 --catalog tableflow$(RESET)"
	@cat tables.sql | docker exec -i trino trino --server localhost:8080 --catalog tableflow --schema "lkc-3gmgdj"
	@echo "$(BOLD)$(GREEN)✅ Queries executed!$(RESET)"

# Clean up
.PHONY: clean
clean:
	@echo "$(BOLD)$(YELLOW)🧹 Cleaning up TableFlow services...$(RESET)"
	docker compose down -v
	@echo "$(BOLD)$(GREEN)✅ Cleanup complete!$(RESET)"
