variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}


variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string
  sensitive   = true
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "ccx13" # Lowest dedicated server - 2 vCPU, 8GB RAM, 80GB NVMe SSD 20TB traffic
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1" # Nuremberg, Germany
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "turbogate.app"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of 'dev', 'staging', or 'prod'."
  }

}

variable "allowed_ssh_ips" {
  description = "List of IP addresses/CIDR blocks allowed to SSH (IMPORTANT: Restrict this!)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # CHANGE THIS! Use your actual IP ranges
  
  validation {
    condition = length(var.allowed_ssh_ips) > 0
    error_message = "At least one SSH IP range must be specified."
  }
}


variable "fail2ban_config" {
  description = "fail2ban configuration parameters"
  type = object({
    bantime   = number
    findtime  = number
    maxretry  = number
    ssh_maxretry = number
  })
  default = {
    bantime      = 3600  # 1 hour ban
    findtime     = 600   # 10 minutes window
    maxretry     = 5     # General max retries
    ssh_maxretry = 3     # SSH specific max retries
  }
}

variable "enable_security_hardening" {
  description = "Enable comprehensive security hardening"
  type        = bool
  default     = true
}

