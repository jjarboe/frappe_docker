.PHONY: build up down

# This is the primary command for developers to build the project.
# It runs our builder container, which then orchestrates the real build.
build:
	@echo "--- Running build orchestrator ---"
	@docker compose run --build --rm builder
	@echo "--- Build complete ---"

start: build
	@echo "--- Starting application ---"
	@make up

# Starts the application in detached mode using the images created by 'make build'
up:
	docker compose up --remove-orphans -d

# Stops and removes the application containers
down:
	docker compose down --remove-orphans
