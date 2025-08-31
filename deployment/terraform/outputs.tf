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

# Certificate Outputs - UPDATED for Certbot certificates
output "certificate_domains" {
  value       = var.ssl_certificate_type == "certbot" ? [var.domain_name, "www.${var.domain_name}"] : []
  description = "Domains covered by Certbot certificates"
}

output "certificate_id" {
  value       = var.ssl_certificate_type == "certbot" ? "Managed by Certbot on servers" : "N/A"
  description = "Certificate management method"
}

output "certificate_info" {
  value = {
    type           = var.ssl_certificate_type
    location       = var.ssl_certificate_type == "certbot" ? "/etc/letsencrypt/live/${var.domain_name}/" : "N/A"
    auto_renewal   = var.ssl_certificate_type == "certbot" ? "Enabled via cron job" : "N/A"
    management     = var.ssl_certificate_type == "certbot" ? "Server-side with Certbot" : "Hetzner managed"
  }
  description = "SSL certificate configuration details"
}

# DNS Configuration Instructions
output "dns_configuration" {
  value = var.enable_load_balancer ? {
    instructions = "Configure your DNS as follows:"
    a_record     = "${var.domain_name} → ${hcloud_load_balancer.main[0].ipv4}"
    aaaa_record  = "${var.domain_name} → ${hcloud_load_balancer.main[0].ipv6}"
    www_record   = "www.${var.domain_name} → ${var.domain_name} (CNAME)"
    important    = "SSL certificates are managed by Certbot on servers"
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
    waf_health   = var.enable_load_balancer ? "http://${hcloud_load_balancer.main[0].ipv4}/waf-health" : "N/A"
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
    ssl_handling       = "Certbot on servers"  # UPDATED
    certificate_renewal = "Automated via cron"  # ADDED
    high_availability  = var.enable_load_balancer ? "Yes (${length(hcloud_server.worker) + 1} nodes)" : "No"
    server_type        = var.server_type
    location           = var.location
  }
  description = "Deployment configuration summary"
}

# Network Information
output "network_topology" {
  value = {
    main_network       = hcloud_network.main.ip_range
    management_subnet  = hcloud_network_subnet.main.ip_range
    application_subnet = hcloud_network_subnet.application.ip_range
    database_subnet    = hcloud_network_subnet.database.ip_range
    monitoring_subnet  = hcloud_network_subnet.monitoring.ip_range  # ADDED
    load_balancer_ip   = var.enable_load_balancer ? hcloud_load_balancer_network.main[0].ip : "N/A"
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
    ssl_certificates  = "Certbot with auto-renewal"  # UPDATED
  }
  description = "Security configuration status"
}

# Cost Estimation
output "estimated_monthly_cost" {
  value = {
    servers       = "${(1 + length(hcloud_server.worker)) * 8.50} EUR (${var.server_type})"
    load_balancer = var.enable_load_balancer ? "5.39 EUR (${var.load_balancer_type})" : "0 EUR"
    certificates  = "0 EUR (Let's Encrypt via Certbot)"  # ADDED
    total         = "${var.enable_load_balancer ? (1 + length(hcloud_server.worker)) * 8.50 + 5.39 : (1 + length(hcloud_server.worker)) * 8.50} EUR"
    note          = "Plus traffic costs (1 EUR per TB outgoing after included traffic)"
  }
  description = "Estimated monthly infrastructure costs"
}

# SSL Certificate Management Information
output "ssl_certificate_management" {
  value = {
    type          = "Let's Encrypt via Certbot"
    domains       = [var.domain_name, "www.${var.domain_name}"]
    location      = "/etc/letsencrypt/live/${var.domain_name}/"
    renewal_cron  = "0 2 */15 * * (every 15 days at 2 AM)"
    renewal_command = "/usr/bin/certbot renew --quiet && docker service update --force turbogate_nginx"
    validation    = "HTTP-01 challenge via webroot"
    cost          = "Free (Let's Encrypt)"
  }
  description = "SSL certificate management details"
}

# Deprecated - Floating IP (for backward compatibility)
output "floating_ip" {
  value       = "DEPRECATED - Use load_balancer_ip instead"
  description = "DEPRECATED: Floating IP has been replaced by Load Balancer"
}