## v0.2.0 (2025-07-16)

### feat

- ensuring that Prod will not run without secret key
- Dockerfile for containerisation
- displaying the env for the gateway/health end point
- addition of gevent & debuggy libraries
- addition of gevent & dubugpy
- added testingconfig
- add standalone development server runner for TurboGate
- add standalone health check script for TurboGate gateway and services
- implement Flask app factory with CLI and health check for TurboGate
- add API Gateway blueprint with health checks, service routing, auth, and metrics
- add core service utilities for inter-service comms, auth and health checks
- Implement core API gateway middleware
- Enhance project metadata and dependencies
- update package metadata and version to 0.1.0
- add configuration for microservices and routing in Flask app
- implement utility functions for logging and Redis client management
- add redis dependency for Redis database support
- add structlog dependency for structured logging

### fix

- changed prod_run command to inject  .env
-  changed dicord message
- CI Sleep Time & changed notifcation to webhook_url
- webhook ci
- discord notification ci
- dicord notifications
- dicord notification
- checking without dicord notfircatiion
- ci pipeline format
- run_dev.py script
- removed repeated import
- assigning to dev & not development & changed TESTING to TEST
-  missed an import

### build

- ci should now run only on push to main & also when pull_requests are created
- addition of prod curl test & also discord notify
- CI Pipeline
- removed dev stage
- makefile for easy access to commands

### refactor

- dev & prod from development & production
- expose create_routes via package __init__ for cleaner imports
-  Moves utility function imports into `__init__.py` to simplify consumption of core utils.

### test

- test & script packages __init__.py files
- add integration tests for gateway routes
- add unit tests for Flask app factory
- add Pytest fixtures for app, client, and CLI runner

### style

- format

### chore

- removing testing with dubbgy
- upgrade certifi package
- run_dev.py modifiocation
- .dockerignore preventing of .env files getting copied over
- increased worker count for prod
- changed the make commands to use snake case

## v0.1.0 (2025-07-12)

### feat

- initialize project with Poetry configuration

### fix

- update commitizen version to match tool.poetry.version

### chore

- GitHub Actions workflow for version bump and release creation
