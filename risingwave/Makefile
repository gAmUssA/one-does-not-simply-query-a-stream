GREEN=\033[0;32m
NC=\033[0m # No Color

base: create topic info

create:
	docker compose up -d

	@echo "\n⏳ Waiting for Kafka to be ready..."
	@while ! nc -z localhost 29092; do \
		sleep 1; \
		echo "Waiting for Kafka..."; \
	done
	@printf "$(GREEN)✔$(NC) 🪲 Kafka is ready!\n"

	@echo "\n⏳ Waiting for RisingWave to be ready..."
	@while ! nc -z localhost 4566; do \
		sleep 1; \
		echo "Waiting for RisingWave..."; \
	done
	@printf "$(GREEN)✔$(NC) 🌊 RisingWave is ready!\n"

topic:
	docker exec kafka kafka-topics.sh \
		--bootstrap-server localhost:9092 \
		--create \
		--topic input-topic

	docker exec kafka kafka-topics.sh \
    		--bootstrap-server localhost:9092 \
    		--create \
    		--topic output-topic

info:     	
	@printf "\n==========================================================\n"
	@printf "🦊 Redpanda Console:		\033[4mhttp://localhost:9080\033[0m\n"
	@printf "==========================================================\n"

destroy:
	docker compose down -v

run-client:
	docker-compose exec -it psql-client psql -h risingwave -p 4566 -d dev -U root

run-kafka-producer:
	docker-compose exec -it kafka kafka-console-producer.sh --broker-list localhost:9092 --topic input-topic