## v0.9.48 (2025-09-01)

### fix

- tyhj

## v0.9.47 (2025-09-01)

### fix

- work

## v0.9.46 (2025-09-01)

### fix

- who knows knows

## v0.9.45 (2025-09-01)

### fix

- work work

## v0.9.44 (2025-09-01)

### fix

- work work

## v0.9.43 (2025-09-01)

### fix

- work

## v0.9.42 (2025-09-01)

### fix

- work

## v0.9.41 (2025-09-01)

### fix

- who knows

## v0.9.40 (2025-09-01)

### fix

- work

## v0.9.39 (2025-09-01)

### fix

- work

## v0.9.38 (2025-09-01)

### fix

- image not gettiing pulled

## v0.9.37 (2025-09-01)

### fix

- work

## v0.9.36 (2025-09-01)

### fix

- work

## v0.9.35 (2025-09-01)

### fix

-  work

## v0.9.34 (2025-09-01)

### fix

- work

## v0.9.33 (2025-09-01)

### fix

- work

## v0.9.32 (2025-09-01)

## v0.9.31 (2025-09-01)

### fix

- deploy

## v0.9.30 (2025-09-01)

### fix

- WAF

## v0.9.29 (2025-09-01)

### fix

- deploy

## v0.9.28 (2025-09-01)

### fix

- add  check on secret gettings passed

## v0.9.27 (2025-09-01)

### fix

- managed

## v0.9.26 (2025-09-01)

### fix

- removing ssl

## v0.9.25 (2025-09-01)

### fix

- will manage this later on

## v0.9.24 (2025-09-01)

### fix

- remove Duplicate variable declaration

## v0.9.23 (2025-09-01)

### fix

- dns lb

## v0.9.22 (2025-08-31)

### fix

- bump bump

## v0.9.21 (2025-08-31)

### fix

- The hcloud_load_balancer_service_certificate resource block has been deleted.

## v0.9.20 (2025-08-31)

### fix

- who knows

## v0.9.19 (2025-08-31)

### fix

-  detailed logs

## v0.9.18 (2025-08-31)

### fix

- should not ssh into lb

## v0.9.17 (2025-08-31)

### fix

- bump me up my g

## v0.9.16 (2025-08-31)

### fix

- removing repeated checks

## v0.9.15 (2025-08-31)

### fix

- bump me up my g

## v0.9.14 (2025-08-31)

### fix

- installing depe first

## v0.9.13 (2025-08-31)

### fix

- who knows

## v0.9.12 (2025-08-31)

### fix

- we are deployiong

## v0.9.11 (2025-08-31)

### fix

- hardening the servers only

## v0.9.10 (2025-08-31)

### fix

- check fail ban installtiioon & is active

## v0.9.9 (2025-08-31)

### fix

- from "'workers' in group_names" to "'swarm_workers' in group_names"

## v0.9.8 (2025-08-31)

### fix

- targeting hosts: swarm_managers:swarm_workers & also allowing internal ssh

## v0.9.7 (2025-08-31)

### fix

- indentation

## v0.9.6 (2025-08-31)

### fix

- yaml formating

## v0.9.5 (2025-08-31)

### fix

-  removed managed certs as cerbot is handling these

## v0.9.4 (2025-08-31)

### fix

- UPDATED with explicit dependencies

## v0.9.3 (2025-08-31)

## v0.9.2 (2025-08-31)

### fix

- reducing the number of workers

## v0.9.1 (2025-08-31)

### fix

- invalid path was used Invalid value for "path" parameter: no file exists at │ "./scripts/node_init.sh"

## v0.9.0 (2025-08-31)

### feat

- lb & infra

## v0.8.6 (2025-08-31)

### fix

- The inventory.tpl template needs to be adjusted to handle the dynamic worker count:

## v0.8.5 (2025-08-31)

### fix

- bump needs to ruun

## v0.8.4 (2025-08-31)

### fix

- dynamic scalling

## v0.8.3 (2025-08-31)

### fix

- h

## v0.8.2 (2025-08-31)

### fix

- use an algorithm block with a type parameter instead of the algorithm_type parameter directly.

## v0.8.1 (2025-08-31)

### fix

- resolve hcloud provider compatibility issues

## v0.8.0 (2025-08-31)

### feat

- conditional load balancer creation and ansible inventory template

### fix

- correct firewall attachment for load balancer resources

## v0.7.31 (2025-08-30)

### fix

- update Docker Swarm real IP configuration to use correct subnet mask

## v0.7.30 (2025-08-30)

### fix

- update Docker Swarm real IP configuration to use correct subnet mask
- adjust nginx service configuration for host mode to preserve real client IPs

## v0.7.29 (2025-08-30)

### fix

- update real IP configuration for Docker Swarm and add debug headers location

## v0.7.28 (2025-08-30)

### fix

- update real IP header to use X-Forwarded-For and enhance log format for accurate IP logging

## v0.7.27 (2025-08-30)

### fix

- correct real IP configuration for Docker setup and update log format for accurate IP logging

## v0.7.26 (2025-08-30)

### fix

- update real IP configuration to trust specific subnets for accurate logging

## v0.7.25 (2025-08-30)

### fix

- update real IP header to use X-Real-IP for accurate logging

## v0.7.24 (2025-08-30)

### fix

- enhance real IP handling and improve log format for better debugging

## v0.7.23 (2025-08-30)

### fix

- updating gunicorn & flask-cors to patch security valnurabilities

## v0.7.22 (2025-08-29)

## v0.7.21 (2025-08-29)

### fix

- remove read_only option from nginx service in docker-compose template

## v0.7.20 (2025-08-29)

### fix

- update healthcheck endpoint and improve nginx temporary cache paths

## v0.7.19 (2025-08-29)

### fix

- update nginx config target path to use nginx.conf instead of default.conf

## v0.7.18 (2025-08-29)

### refactor

- reorganize nginx configuration for improved structure and readability

## v0.7.17 (2025-08-29)

### fix

- ensure nginx_config alias is created before deleting temporary file for compatibility

## v0.7.16 (2025-08-29)

### fix

- create NGINX cache subdirectories and set permissions for improved caching

## v0.7.15 (2025-08-29)

### fix

- add /run tmpfs mount for nginx service to enhance security

## v0.7.14 (2025-08-29)

### fix

- add /run tmpfs mount for nginx service to improve security

## v0.7.13 (2025-08-29)

### fix

- remove unnecessary user specification for nginx service in docker-compose

## v0.7.12 (2025-08-29)

### fix

- update tmpfs configuration for turbogate service to enhance security and permissions

## v0.7.11 (2025-08-29)

### fix

- enhance Dockerfile so that .env is not recreated at run rime and dremoved the tmp localtions as they should not be needed

## v0.7.10 (2025-08-29)

### fix

- update non-root user ID for turbogate service in docker-compose

## v0.7.9 (2025-08-29)

### fix

- update redis service networks from turbogate_backend to turbogate_database

## v0.7.8 (2025-08-29)

### fix

- update redis service network from turbogate_database to turbogate_backend

## v0.7.7 (2025-08-29)

### refactor

- add tmpfs for cache directory in docker-compose

## v0.7.6 (2025-08-29)

### refactor

- enhance security configurations and update service constraints in docker-compose

## v0.7.5 (2025-08-29)

### refactor

- comment out unused security checks in swarm setup

## v0.7.4 (2025-08-29)

### refactor

- improve SSH hardening commands for consistency

## v0.7.3 (2025-08-29)

### refactor

- replace network security verification with detailed network information retrieval

## v0.7.2 (2025-08-28)

### refactor

- remove old unencrypted turbogate_network cleanup task

## v0.7.1 (2025-08-28)

### fix

- convert boolean values to strings for Docker node labels

## v0.7.0 (2025-08-28)

### feat

- enhance Docker Swarm security with encrypted networks and verification tasks

## v0.6.3 (2025-08-28)

### fix

- Ansible inventory generation with static IPs and security configurations

## v0.6.2 (2025-08-28)

### fix

- add internal IPs for manager and workers in Ansible inventory generation

## v0.6.1 (2025-08-28)

### refactor

- update inventory template for dynamic IP assignment and security configurations

## v0.6.0 (2025-08-28)

### feat

- add Terraform destroy step to CI/CD workflow
- add security hardening playbook for TurboGate infrastructure

### refactor

- remove Terraform destroy step from CI/CD workflow

## v0.5.1 (2025-08-28)

### refactor

- remove Terraform destroy step from CD workflow

## v0.5.0 (2025-08-28)

### feat

- add Terraform destroy step

## v0.4.1 (2025-08-28)

### fix

- add dependency on main firewall for worker nodes

## v0.4.0 (2025-08-28)

### feat

- add unattended upgrades and fail2ban configuration templates

## v0.3.0 (2025-08-28)

### feat

- enhanced server security with multiple firewalls and basic hardening

## v0.2.0 (2025-08-28)

### feat

- add additional network subnets and enhance firewall rules for security segmentation

### fix

- update gevent version specification in pyproject.toml to the latest build of this failing will need to change this back down the line

## v0.1.0 (2025-08-28)

### feat

- add new variables for environment, allowed SSH IPs, fail2ban config, and security hardening

## v0.0.1 (2025-08-22)

### chore

- lets work :)
