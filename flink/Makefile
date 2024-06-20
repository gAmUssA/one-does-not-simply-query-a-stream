GREEN=\033[0;32m
NC=\033[0m # No Color

base: create info run-client

create:
	docker compose build --no-cache
	docker compose up -d

	@echo "\n⏳ Waiting for Kafka to be ready..."
	@while ! nc -z localhost 29092; do \
		sleep 1; \
		echo "Waiting for Kafka..."; \
	done
	@printf "$(GREEN)✔$(NC) 🪲 Kafka is ready!\n"

info:     	
	@printf "\n==========================================================\n"
	@printf "🦊 Redpanda Console:		\033[4mhttp://localhost:9080\033[0m\n"
	@printf "🐿️ Flink Console:		\033[4mhttp://localhost:8081\033[0m\n"
	@printf "==========================================================\n"

destroy:
	docker compose down -v

run-client:
	docker-compose run sql-client
