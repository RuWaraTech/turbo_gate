
.PHONY: install run test clean build docker-build docker-run lint format

# Variables
APP_NAME = turbogate
PYTHON = python3

# Install dependencies
install:
	poetry install

# Install development dependencies
install_dev:
	poetry install --with dev,test

# Run development server
run:
	poetry run python -m scripts.run_dev

# Run with Poetry script
dev:
	poetry run dev-server

# Run tests
test:
	poetry run pytest tests/ -v

# Run tests with coverage
test_coverage:
	poetry run pytest tests/ --cov=gateway_service --cov-report=html

# Lint code
lint:
	poetry run flake8 gateway_service/ tests/
	poetry run mypy gateway_service/

# Format code
format:
	poetry run black gateway_service/ tests/ scripts/
	poetry run isort gateway_service/ tests/ scripts/

# Clean up
clean:
	find . -type d -name __pycache__ -delete
	find . -type f -name "*.pyc" -delete
	rm -rf .pytest_cache/
	rm -rf htmlcov/
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info/

# Build package
build:
	poetry build

# Version bump
bump:
	poetry run cz bump

# Install pre-commit hooks
pre_commit:
	poetry run pre-commit install

# Health check
health:
	poetry run health-check

# Docker commands
docker_build:
	docker build -t $(APP_NAME):latest .

docker-run:
	docker run -p 5000:5000 --env-file .env $(APP_NAME):latest

# Development with Docker Compose
dev_up:
	docker compose up -d

dev_down:
	docker compose down

dev_logs:
	docker compose logs -f turbogate

# Production commands
prod_build:
	docker build -t $(APP_NAME):prod --target prod .

prod_run:
	docker run -p 5000:5000 -e FLASK_ENV=prod $(APP_NAME):prod
