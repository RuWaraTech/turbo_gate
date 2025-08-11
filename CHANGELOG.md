## v0.8.0 (2025-08-11)

### feat

- integrate Terraform-generated Ansible inventory for CD pipeline
- assigning  manager the floating ip
- add Hetzner Cloud infrastructure for TurboGate Docker Swarm cluster
- making the ssh sensitive so it does not get displayed at run time
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
- initialize project with Poetry configuration

### fix

- reset of tags
- whatever
- network name change
- moving to enviroments instead of docker secrets
- no logss
- no_log
- 3
- trying to see if secrest are passed
- debug will rotatae the keys
- swarm_managers renaming
- template
- meh
- nodes: true addition
- wrong parathesis
- syntax issue
- do not run if already connected
- local_manager_node.Status directly holds the string value "ready".
- we go agaiin
- something
- swarm status messages
- swarm  reportiing
- roll of dice
- addtion of internal ips for docker swarm
-  workers to join using managers internal ip
-  get internal_network
- hameno
- we go again
- docker signing keys
- reverting back to working setup
- correct Python interpreter and netaddr installation for Docker Swarm setup
- using pip to install netaddr
- rerunning setup
- removing setup swarm
- updown
- it is what it is
- networking
- who knows at this point
- removing IPv6 configuration
- missed \  so variable was not getting passed
- removed "" from floating ip
- moved the -e "floating_ip=${{ needs.deploy-infrastructure.outputs.floating_ip }}"  flag to the right place
- removed comments as they are breaking the run
- TASK [Configure floating IP interface] ***************************************** fatal: [manager]: FAILED! => {"msg": "The task includes an option with an undefined variable.. 'floating_ip' is undefined\n\nThe error appears to be in '/home/runner/work/turbo_gate/turbo_gate/deployment/ansible/playbooks/setup_swarm.yml': line 7, column 7, but may\nbe elsewhere in the file depending on the exact syntax problem.\n\nThe offending line appears to be:\n\n    # -- NEW TASK ADDED HERE --\n    - name: Configure floating IP interface\n      ^ here\n"} PLAY RECAP *********************************************************************
- assigning the floating ip
- installation of jsondiff library
- Error: Duplicate output definition │ │   on outputs.tf line 5: │    5: output "floating_ip" { │ │ An output named "floating_ip" was already defined at main.tf:147,1-21. │ Output names must be unique within a module.
- passing the SSH_PRIVATE_KEY to TF Plan
- removed comments
- dev work
- reverting back as I am certain the previus change was closer to solution
-  moving nginx  file under play book folder
- refactored ansible files for app deployment
-  app deployment has the wrong prefix
- I was not passing s3 backend to all TF Actions
- matching versions of terraform
-  CCX13 is not recognised & only ccx13 is as a valid server name
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
- update commitizen version to match tool.poetry.version

### build

- removed terraform backend setup in the CD Pipeline this is not required
- terraform.lock.hcl file
- updated .gitignore to exlcude  terraform files like the .tfstate &  .tfvars
- offloading  terraform state file to hetzner s3 bucket
- version 1.6.6 & skipping_requesting_account_id
- CID Build TF
- removing version & also adding KEY & SECRET to Terrafrom INIT
- changes endpoint to endpoinds
-  fixing the endpoint for s3 container
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
- ci should now run only on push to main & also when pull_requests are created
- addition of prod curl test & also discord notify
- CI Pipeline
- removed dev stage
- makefile for easy access to commands

### refactor

- Containerize NGINX within Docker Swarm stack
- ensuring that prod is at the end do by default this will be the entry point  when this build with out a target
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

- removed file from folder
- define Terraform backend and provider requirements
- removing testing with dubbgy
- upgrade certifi package
- run_dev.py modifiocation
- .dockerignore preventing of .env files getting copied over
- increased worker count for prod
- changed the make commands to use snake case
- GitHub Actions workflow for version bump and release creation
