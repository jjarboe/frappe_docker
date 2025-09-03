ARGS ?=
UP_ARGS ?=

.PHONY: build up down

# This is the primary command for developers to build the project.
# It runs our builder container, which then orchestrates the real build.
build:
	@echo "--- Running build orchestrator with args: $(ARGS) ---"
	@docker compose run --build --rm builder $(ARGS)
	@echo "--- Build complete ---"

start: build
	@echo "--- Starting application ---"
	@make up

debug: build
	@make up UP_ARGS="-f compose.yml -f compose.jon-debug.yml"

# Starts the application in detached mode using the images created by 'make build'
up:
	docker compose up --remove-orphans -d $(UP_ARGS)

# Stops and removes the application containers
down:
	docker compose down --remove-orphans
