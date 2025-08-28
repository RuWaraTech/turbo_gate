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
