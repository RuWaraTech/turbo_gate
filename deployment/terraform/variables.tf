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
  default     = "ridebase.app"
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

variable "worker_count" {
  description = "Number of worker nodes to create"
  type        = number
  default     = 3
  
  validation {
    condition     = var.worker_count >= 1 && var.worker_count <= 10
    error_message = "Worker count must be between 1 and 10."
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

# Load Balancer Configuration
variable "enable_load_balancer" {
  description = "Enable Hetzner Cloud Load Balancer"
  type        = bool
  default     = true
}

variable "load_balancer_type" {
  description = "Hetzner Load Balancer type"
  type        = string
  default     = "lb11"
  
  validation {
    condition     = contains(["lb11", "lb21", "lb31"], var.load_balancer_type)
    error_message = "Load balancer type must be one of: lb11, lb21, lb31"
  }
}

variable "load_balancer_algorithm" {
  description = "Load balancing algorithm"
  type        = string
  default     = "least_connections"
  
  validation {
    condition     = contains(["round_robin", "least_connections"], var.load_balancer_algorithm)
    error_message = "Algorithm must be either 'round_robin' or 'least_connections'"
  }
}

variable "enable_sticky_sessions" {
  description = "Enable sticky sessions on the load balancer"
  type        = bool
  default     = true
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 15
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 10
}

variable "health_check_retries" {
  description = "Number of health check retries before marking unhealthy"
  type        = number
  default     = 3
}

# Traefik + ModSecurity WAF Configuration
variable "traefik_enabled" {
  description = "Enable Traefik proxy with ModSecurity WAF"
  type        = bool
  default     = true
}

variable "modsec_rule_engine" {
  description = "ModSecurity rule engine mode (On, Off, DetectionOnly)"
  type        = string
  default     = "On"

  validation {
    condition     = contains(["On", "Off", "DetectionOnly"], var.modsec_rule_engine)
    error_message = "ModSecurity rule engine must be On, Off, or DetectionOnly"
  }
}

variable "modsec_paranoia_level" {
  description = "ModSecurity paranoia level (1-4, higher = more strict)"
  type        = number
  default     = 1

  validation {
    condition     = var.modsec_paranoia_level >= 1 && var.modsec_paranoia_level <= 4
    error_message = "ModSecurity paranoia level must be between 1 and 4"
  }
}

variable "modsec_replicas" {
  description = "Number of ModSecurity WAF replicas"
  type        = number
  default     = 2
  
  validation {
    condition     = var.modsec_replicas >= 1 && var.modsec_replicas <= 10
    error_message = "ModSecurity replicas must be between 1 and 10"
  }
}

variable "traefik_dashboard_auth" {
  description = "Basic auth credentials for Traefik dashboard (user:password_hash format)"
  type        = string
  default     = "admin:$apr1$ruca84Hq$mbjdMZBAG.KWn7vfN/SNK/"
  sensitive   = true
}

variable "rate_limit_average" {
  description = "Average requests per second for rate limiting"
  type        = number
  default     = 10
}

variable "rate_limit_burst" {
  description = "Burst requests allowed for rate limiting"
  type        = number
  default     = 20
}

# SSL Configuration - UPDATED for Certbot certificates
variable "enable_ssl_redirect" {
  description = "Enable automatic HTTP to HTTPS redirect at Traefik level"
  type        = bool
  default     = true
}

variable "ssl_certificate_type" {
  description = "Type of SSL certificate (certbot, managed, or uploaded)"
  type        = string
  default     = "managed"  # CHANGED from "managed" to "certbot"
  
  validation {
    condition     = contains(["certbot", "managed", "uploaded"], var.ssl_certificate_type)
    error_message = "Certificate type must be one of: 'certbot', 'managed', or 'uploaded'"
  }
}

variable "ssl_domains" {
  description = "Domains for SSL certificate (used for reference only with Certbot)"
  type        = list(string)
  default     = []
}

# PROXY Protocol Configuration
variable "enable_proxy_protocol" {
  description = "Enable PROXY protocol for preserving client IPs"
  type        = bool
  default     = true
}

# Traefik Deployment Configuration
variable "traefik_deployment_mode" {
  description = "Traefik deployment mode (global or replicated)"
  type        = string
  default     = "replicated"
  
  validation {
    condition     = contains(["global", "replicated"], var.traefik_deployment_mode)
    error_message = "Traefik deployment mode must be either 'global' or 'replicated'"
  }
}

variable "traefik_replicas" {
  description = "Number of Traefik replicas (only used if deployment_mode is replicated)"
  type        = number
  default     = 2
  
  validation {
    condition     = var.traefik_replicas >= 1 && var.traefik_replicas <= 10
    error_message = "Traefik replicas must be between 1 and 10"
  }
}


