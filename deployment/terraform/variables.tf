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

variable "admin_ips" {
  description = "List of admin IP addresses for SSH access"
  type        = list(string)
  default = [
    "86.28.208.241/32" # <---  Add your IP here
  ]
}

variable "enable_bastion" {
  description = "Enable a bastion host for secure access"
  type        = bool
  default     = false
}
