## v0.4.4 (2025-07-18)

### fix

-  app deployment has the wrong prefix

## v0.4.3 (2025-07-18)

### fix

- I was not passing s3 backend to all TF Actions

## v0.4.2 (2025-07-18)

## v0.4.1 (2025-07-18)

### fix

- matching versions of terraform

## v0.4.0 (2025-07-18)

### feat

- making the ssh sensitive so it does not get displayed at run time

### fix

-  CCX13 is not recognised & only ccx13 is as a valid server name

### build

- removed terraform backend setup in the CD Pipeline this is not required
- terraform.lock.hcl file
- updated .gitignore to exlcude  terraform files like the .tfstate &  .tfvars
- offloading  terraform state file to hetzner s3 bucket

## v0.3.5 (2025-07-18)

### build

- version 1.6.6 & skipping_requesting_account_id

## v0.3.4 (2025-07-18)

### build

- CID Build TF

## v0.3.3 (2025-07-18)

### build

- removing version & also adding KEY & SECRET to Terrafrom INIT

## v0.3.2 (2025-07-18)

### build

- changes endpoint to endpoinds

## v0.3.1 (2025-07-18)

### build

-  fixing the endpoint for s3 container

## v0.3.0 (2025-07-17)

### feat

- using s3 bucket for storing terraform statefiles
- add automated deployment triggered by CI success or manual dispatch
- add production deployment script with Terraform and Ansible
- configure secure stack with secret management and internal networks
- configure NGINX as reverse proxy with load balancing and rate limiting
- define Docker Swarm stack for TurboGate with NGINX, Redis, and secrets
- add initial Ansible inventory structure for Swarm cluster
- add Ansible role to set up NGINX reverse proxy with SSL for TurboGate
- add Ansible playbook to deploy TurboGate stack on Swarm managers
- add Ansible playbook to automate Docker Swarm cluster setup
- add Terraform outputs for manager IP, floating IP, and worker node IPs
- provision Hetzner cloud infrastructure for TurboGate with manager and worker nodes
- define core infrastructure variables for Hetzner Cloud

### build

- changes the endpoints s3 from versions to CD during deployment
- changes to  cd pipeline, I need this to run after bump has ran
- reverting back to main for deployments
- deply AGS_0003_Infrastructure
- deploy AGS_0003_Infrastructure branch
-  I want to see the cd run
- updated CI to pull user information instead of the bot
- moving to run on every push
- updated notification in CI to include Author and also better formating
- updated notification
- removed coverage results upload
- improved CI
- on pull_request only as running the same on merge to main makes no sense

### refactor

- ensuring that prod is at the end do by default this will be the entry point  when this build with out a target

### chore

- removed file from folder
- define Terraform backend and provider requirements

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
