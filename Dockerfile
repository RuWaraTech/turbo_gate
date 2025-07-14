# Stage 1: Base Stage
FROM python:3.13 AS base

# Set environment variables for Python optimization
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    POETRY_VERSION=1.8.3 \
    POETRY_HOME=/opt/poetry \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=false

# Install Poetry using the official installer
RUN apt-get update \
    && apt-get install -y curl \
    && curl -sSL https://install.python-poetry.org | python3 - --version $POETRY_VERSION \
    && apt-get upgrade -y \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Add Poetry to PATH
ENV PATH=$POETRY_HOME/bin:$PATH

# Set working directory
WORKDIR /gateway_app

# Copy dependency files first for better caching
COPY pyproject.toml ./

# Install dependencies
RUN poetry install --no-ansi --no-interaction --no-root --only main

# Copy the app code after dependencies are installed
COPY gateway_service /gateway_app/gateway_service
COPY scripts /gateway_app/scripts

# Install the project itself
RUN poetry install --no-ansi --no-interaction --only-root

# Stage 2: Production Stage
FROM python:3.13-slim AS prod

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH=/opt/poetry/bin:$PATH

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash --uid 1001 app

# Copy Poetry and dependencies from base stage
COPY --from=base --chown=app:app /opt/poetry /opt/poetry
COPY --from=base --chown=app:app /usr/local/lib/python3.13/site-packages /usr/local/lib/python3.13/site-packages
COPY --from=base --chown=app:app /usr/local/bin /usr/local/bin

# Set working directory and copy application
WORKDIR /gateway_app
COPY --from=base --chown=app:app /gateway_app /gateway_app

# Switch to non-root user
USER app

# Create volume for persistent data
VOLUME /gateway_app/data

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/gateway/health')" || exit 1

# Use exec form for better signal handling
CMD ["poetry", "run", "gunicorn", \
     "--bind", "0.0.0.0:5000", \
     "--worker-class", "gevent", \
     "--workers", "4", \
     "--worker-connections", "1000", \
     "--timeout", "120", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "gateway_service.app:create_app()"]

EXPOSE 5000

# Stage 3: Development Stage
FROM python:3.13-slim AS dev

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH=/opt/poetry/bin:$PATH \
    FLASK_ENV=development \
    FLASK_DEBUG=1

# Install additional dev tools
RUN apt-get update \
    && apt-get install -y git curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Poetry and all dependencies from base stage
COPY --from=base /opt/poetry /opt/poetry
COPY --from=base /usr/local/lib/python3.13/site-packages /usr/local/lib/python3.13/site-packages
COPY --from=base /usr/local/bin /usr/local/bin

# Set working directory and copy application
WORKDIR /gateway_app
COPY --from=base /gateway_app /gateway_app

# Install development dependencies
RUN poetry install --no-ansi --no-interaction --with dev

# Use debugpy for remote debugging with hot reload
CMD ["poetry", "run", "python", "-Xfrozen_modules=off", "-m", "debugpy", \
     "--listen", "0.0.0.0:5678", \
     "--wait-for-client", \
     "-m", "scripts.run_dev"]

EXPOSE 5000
EXPOSE 5678

# Stage 4: Test Stage
FROM python:3.13-slim AS test

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH=/opt/poetry/bin:$PATH

# Copy Poetry and all dependencies from base stage
COPY --from=base /opt/poetry /opt/poetry
COPY --from=base /usr/local/lib/python3.13/site-packages /usr/local/lib/python3.13/site-packages
COPY --from=base /usr/local/bin /usr/local/bin

# Set working directory and copy application
WORKDIR /gateway_app
COPY --from=base /gateway_app /gateway_app

# Install test dependencies
RUN poetry install --no-ansi --no-interaction --with test

# Copy test environment file if it exists
COPY tests /gateway_app/tests
COPY .env.test* ./

# Set default test command with coverage
ENTRYPOINT ["poetry", "run", "pytest"]
CMD ["--cov=gateway_service", "--cov-report=term-missing", "--cov-report=html", "-v"]