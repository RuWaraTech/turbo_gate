# Server Infrastructure Outputs
output "manager_ip" {
  value       = hcloud_server.manager.ipv4_address
  description = "Public IPv4 address of the manager node"
}

output "worker_ips" {
  value       = [for s in hcloud_server.worker : s.ipv4_address]
  description = "Public IPv4 addresses of worker nodes"
}

output "internal_network" {
  value = {
    manager = one([for network in hcloud_server.manager.network : network.ip if network.network_id == hcloud_network.main.id])
    workers = [for s in hcloud_server.worker : one([for network in s.network : network.ip if network.network_id == hcloud_network.main.id])]
  }
  description = "Internal network IPs"
}

# Load Balancer Outputs (conditional on var.enable_load_balancer)
output "load_balancer_ip" {
  value       = var.enable_load_balancer ? hcloud_load_balancer.main[0].ipv4 : null
  description = "Public IPv4 address of the load balancer - use this for DNS A record"
}

output "load_balancer_ipv6" {
  value       = var.enable_load_balancer ? hcloud_load_balancer.main[0].ipv6 : null
  description = "Public IPv6 address of the load balancer - use this for DNS AAAA record"
}

output "load_balancer_targets" {
  value = var.enable_load_balancer ? {
    manager = hcloud_server.manager.name
    workers = [for s in hcloud_server.worker : s.name]
  } : {
    manager = null
    workers = []
  }
  description = "Servers targeted by the load balancer"
}

# Certificate Outputs
output "certificate_domains" {
  value       = var.enable_load_balancer ? hcloud_managed_certificate.main[0].domain_names : []
  description = "Domains covered by the managed certificate"
}

output "certificate_id" {
  value       = var.enable_load_balancer ? hcloud_managed_certificate.main[0].id : "N/A"
  description = "ID of the managed certificate"
}

# DNS Configuration Instructions
output "dns_configuration" {
  value = var.enable_load_balancer ? {
    instructions = "Configure your DNS as follows:"
    a_record     = "${var.domain_name} → ${hcloud_load_balancer.main[0].ipv4}"
    aaaa_record  = "${var.domain_name} → ${hcloud_load_balancer.main[0].ipv6}"
    www_record   = "www.${var.domain_name} → ${var.domain_name} (CNAME)"
    important    = "Update DNS before certificate validation completes!"
  } : {
    instructions = "Load Balancer disabled - using direct server access"
    a_record     = "${var.domain_name} → ${hcloud_server.manager.ipv4_address}"
  }
  description = "DNS configuration instructions"
}

# Application Access Endpoints
output "application_endpoints" {
  value = {
    main_url     = "https://${var.domain_name}"
    health_check = "https://${var.domain_name}/health"
    gateway      = "https://${var.domain_name}/gateway/health"
    waf_health   = var.enable_load_balancer ? "http://${hcloud_load_balancer.main[0].ipv4}/lb-health" : "N/A"
  }
  description = "Application access endpoints"
}

# Deployment Summary
output "deployment_summary" {
  value = {
    environment        = var.environment
    load_balancer      = var.enable_load_balancer ? "Enabled" : "Disabled"
    waf_enabled        = var.waf_enabled ? "Yes" : "No"
    waf_paranoia_level = var.waf_enabled ? var.waf_paranoia_level : "N/A"
    ssl_handling       = var.enable_load_balancer ? "Managed by Load Balancer" : "Manual Certbot"
    high_availability  = var.enable_load_balancer ? "Yes (${length(hcloud_server.worker) + 1} nodes)" : "No"
    server_type        = var.server_type
    location           = var.location
  }
  description = "Deployment configuration summary"
}

# Network Information
output "network_topology" {
  value = {
    main_network    = hcloud_network.main.ip_range
    management_subnet = hcloud_network_subnet.main.ip_range
    application_subnet = hcloud_network_subnet.application.ip_range
    database_subnet = hcloud_network_subnet.database.ip_range
    load_balancer_ip = var.enable_load_balancer ? "10.0.0.2" : "N/A"
  }
  description = "Network topology information"
}

# Ansible Inventory Path
output "inventory_file_path" {
  value       = local_file.ansible_inventory.filename
  description = "Path to the generated Ansible inventory file"
}

# Security Configuration
output "security_status" {
  value = {
    ssh_firewall       = "Restricted to: ${join(", ", var.allowed_ssh_ips)}"
    fail2ban          = var.enable_security_hardening ? "Enabled" : "Disabled"
    network_encryption = "Docker Swarm TLS Enabled"
    waf_protection    = var.waf_enabled ? "OWASP ModSecurity Active" : "Disabled"
  }
  description = "Security configuration status"
}

# Cost Estimation
output "estimated_monthly_cost" {
  value = {
    servers       = "${(1 + length(hcloud_server.worker)) * 8.50} EUR (${var.server_type})"
    load_balancer = var.enable_load_balancer ? "5.39 EUR (${var.load_balancer_type})" : "0 EUR"
    total         = "${var.enable_load_balancer ? (1 + length(hcloud_server.worker)) * 8.50 + 5.39 : (1 + length(hcloud_server.worker)) * 8.50} EUR"
    note          = "Plus traffic costs (1 EUR per TB outgoing after included traffic)"
  }
  description = "Estimated monthly infrastructure costs"
}

# Deprecated - Floating IP (for backward compatibility)
output "floating_ip" {
  value       = "DEPRECATED - Use load_balancer_ip instead"
  description = "DEPRECATED: Floating IP has been replaced by Load Balancer"
}