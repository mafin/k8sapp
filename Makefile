# Docker Compose shortcuts
DOCKER_COMPOSE_DEV = docker-compose -f docker-compose.yml -f docker-compose.dev.yml

# Build and run
.PHONY: up up-dev down build build-dev

up:
	docker-compose up -d

up-dev:
	$(DOCKER_COMPOSE_DEV) up -d

down:
	docker-compose down

build:
	docker-compose up --build -d

build-dev:
	$(DOCKER_COMPOSE_DEV) up --build -d

# Development tools (require dev container)
.PHONY: test phpstan cs-check cs-fix quality

test:
	$(DOCKER_COMPOSE_DEV) exec app env APP_ENV=test composer test

phpstan:
	$(DOCKER_COMPOSE_DEV) exec app composer phpstan

cs-check:
	$(DOCKER_COMPOSE_DEV) exec app composer cs:check

cs-fix:
	$(DOCKER_COMPOSE_DEV) exec app composer cs:fix

quality:
	$(DOCKER_COMPOSE_DEV) exec app composer quality

# Utility commands
.PHONY: logs shell cache-clear

logs:
	docker-compose logs -f app

shell:
	$(DOCKER_COMPOSE_DEV) exec app sh

cache-clear:
	docker-compose exec app php bin/console cache:clear --env=prod