# Updated outputs.tf for Load Balancer SSL Termination

# Server Infrastructure Outputs
output "manager_ip" {
  value       = hcloud_server.manager.ipv4_address
  description = "Public IPv4 address of the manager node (backend only)"
}

output "worker_ips" {
  value       = [for s in hcloud_server.worker : s.ipv4_address]
  description = "Public IPv4 addresses of worker nodes (backend only)"
}

output "internal_network" {
  value = {
    manager = one([for network in hcloud_server.manager.network : network.ip if network.network_id == hcloud_network.main.id])
    workers = [for s in hcloud_server.worker : one([for network in s.network : network.ip if network.network_id == hcloud_network.main.id])]
  }
  description = "Internal network IPs for backend servers"
}

# Load Balancer Outputs (SSL termination point)
output "load_balancer_ip" {
  value       = var.enable_load_balancer ? hcloud_load_balancer.main[0].ipv4 : null
  description = "Public IPv4 address of the load balancer - SSL termination endpoint"
}

output "load_balancer_ipv6" {
  value       = var.enable_load_balancer ? hcloud_load_balancer.main[0].ipv6 : null
  description = "Public IPv6 address of the load balancer - SSL termination endpoint"
}

output "load_balancer_targets" {
  value = var.enable_load_balancer ? {
    manager = hcloud_server.manager.name
    workers = [for s in hcloud_server.worker : s.name]
    backend_protocol = "HTTP"
    frontend_protocol = "HTTPS"
  } : {
    manager = null
    workers = []
    backend_protocol = null
    frontend_protocol = null
  }
  description = "Servers targeted by the load balancer (HTTP backends)"
}

# Certificate Outputs - Updated for LB managed certificates
output "certificate_domains" {
  value       = var.ssl_certificate_type == "managed" ? [var.domain_name, "www.${var.domain_name}"] : []
  description = "Domains covered by Hetzner managed certificates"
}

output "certificate_id" {
  value       = var.enable_load_balancer && var.ssl_certificate_type == "managed" ? hcloud_managed_certificate.main[0].id : "N/A"
  description = "Hetzner managed certificate ID"
}

output "certificate_info" {
  value = {
    type           = var.ssl_certificate_type
    termination    = var.enable_load_balancer ? "Load Balancer" : "Server-side"
    location       = var.enable_load_balancer ? "Hetzner Load Balancer" : "Backend servers"
    auto_renewal   = var.enable_load_balancer ? "Automatic by Hetzner" : "Manual/Certbot"
    management     = var.enable_load_balancer ? "Hetzner managed" : "Self-managed"
    backend_proto  = var.enable_load_balancer ? "HTTP" : "HTTPS"
  }
  description = "SSL certificate and termination configuration"
}

# DNS Configuration Instructions
output "dns_configuration" {
  value = var.enable_load_balancer ? {
    instructions = "Configure your DNS for Load Balancer SSL termination:"
    a_record     = "${var.domain_name} → ${hcloud_load_balancer.main[0].ipv4}"
    aaaa_record  = "${var.domain_name} → ${hcloud_load_balancer.main[0].ipv6}"
    www_record   = "www.${var.domain_name} → ${var.domain_name} (CNAME)"
    ssl_info     = "SSL certificates are managed by Hetzner at Load Balancer level"
    backend_note = "Backend servers handle HTTP traffic only"
  } : {
    instructions = "Load Balancer disabled - using direct server access"
    a_record     = "${var.domain_name} → ${hcloud_server.manager.ipv4_address}"
    aaaa_record  = "N/A"
    www_record   = "N/A"
    ssl_info     = "SSL managed on servers"
    backend_note = "Backend servers handle HTTPS traffic directly"
  }
  description = "DNS configuration for Load Balancer SSL termination"
}

# Application Access Endpoints
output "application_endpoints" {
  value = {
    main_url     = "https://${var.domain_name}"
    health_check = "https://${var.domain_name}/health"
    gateway      = "https://${var.domain_name}/gateway/health"
    lb_health    = var.enable_load_balancer ? "https://${var.domain_name}/lb-health" : "N/A"
    backend_health = var.enable_load_balancer ? "https://${hcloud_server.manager.ipv4_address}/lb-health" : "N/A"
    ssl_endpoint = var.enable_load_balancer ? "Load Balancer" : "Traefik"
  }
  description = "Application access endpoints with SSL termination info"
}

# Deployment Summary
output "deployment_summary" {
  value = {
    environment        = var.environment
    load_balancer      = var.enable_load_balancer ? "Enabled with SSL termination" : "Disabled"
    ssl_termination    = var.enable_load_balancer ? "Load Balancer" : "Backend servers"
    certificate_type   = var.ssl_certificate_type
    traefik_waf_enabled = var.traefik_enabled ? "Yes (Coraza WAF)" : "No"
    coraza_paranoia_level = var.traefik_enabled ? var.coraza_paranoia_level : "N/A"
    backend_protocol   = var.enable_load_balancer ? "HTTP" : "HTTPS"
    high_availability  = var.enable_load_balancer ? "Yes (${length(hcloud_server.worker) + 1} nodes)" : "No"
    server_type        = var.server_type
    location           = var.location
  }
  description = "Deployment configuration with SSL termination details"
}

# Network Information
output "network_topology" {
  value = {
    main_network       = hcloud_network.main.ip_range
    management_subnet  = hcloud_network_subnet.main.ip_range
    application_subnet = hcloud_network_subnet.application.ip_range
    database_subnet    = hcloud_network_subnet.database.ip_range
    monitoring_subnet  = hcloud_network_subnet.monitoring.ip_range
    load_balancer_ip   = var.enable_load_balancer ? hcloud_load_balancer_network.main[0].ip : "N/A"
    ssl_flow          = var.enable_load_balancer ? "Internet(HTTPS) -> LB(SSL Term) -> Backends(HTTP)" : "Internet(HTTPS) -> Servers(SSL)"
  }
  description = "Network topology with SSL termination flow"
}

# Security Configuration
output "security_status" {
  value = {
    ssh_firewall       = "Restricted to: ${join(", ", var.allowed_ssh_ips)}"
    fail2ban          = var.enable_security_hardening ? "Enabled" : "Disabled"
    network_encryption = "Docker Swarm TLS Enabled"
    waf_protection    = var.traefik_enabled ? "Traefik + Coraza WAF Active" : "Disabled"
    ssl_certificates  = var.enable_load_balancer ? "Hetzner managed at Load Balancer" : "Self-managed"
    ssl_termination   = var.enable_load_balancer ? "Load Balancer" : "Backend servers"
    backend_exposure  = var.enable_load_balancer ? "HTTP only (private)" : "HTTPS (public)"
  }
  description = "Security configuration with SSL termination details"
}

# Cost Estimation
output "estimated_monthly_cost" {
  value = {
    servers       = "${(1 + length(hcloud_server.worker)) * 8.50} EUR (${var.server_type})"
    load_balancer = var.enable_load_balancer ? "5.39 EUR (${var.load_balancer_type})" : "0 EUR"
    certificates  = var.enable_load_balancer ? "0 EUR (included with LB)" : "0 EUR (Let's Encrypt)"
    total         = "${var.enable_load_balancer ? (1 + length(hcloud_server.worker)) * 8.50 + 5.39 : (1 + length(hcloud_server.worker)) * 8.50} EUR"
    note          = "Plus traffic costs (1 EUR per TB outgoing after included traffic)"
    ssl_savings   = var.enable_load_balancer ? "No Certbot renewal complexity" : "Manual certificate management required"
  }
  description = "Cost estimation with SSL termination benefits"
}

# SSL Certificate Management Information
output "ssl_certificate_management" {
  # CORRECTED: Ensured both sides of the conditional have the same keys.
  value = var.enable_load_balancer ? {
    type             = "Hetzner Managed Certificate"
    termination_point = "Load Balancer"
    domains          = [var.domain_name, "www.${var.domain_name}"]
    renewal          = "Automatic by Hetzner"
    backend_protocol = "HTTP"
    cost             = "Free (included with Load Balancer)"
    validation       = "DNS validation (automatic)"
    certificate_id   = var.ssl_certificate_type == "managed" ? hcloud_managed_certificate.main[0].id : "N/A"
  } : {
    type             = "Self-managed"
    termination_point = "Backend servers"
    renewal          = "Manual/Certbot required"
    backend_protocol = "HTTPS"
    domains          = null
    cost             = "Varies"
    validation       = "N/A"
    certificate_id   = "N/A"
  }
  description = "SSL certificate management for Load Balancer termination"
}

# Load Balancer SSL Service Information
output "load_balancer_ssl_info" {
  # CORRECTED: Ensured both sides of the conditional have the same keys.
  value = var.enable_load_balancer ? {
    https_service_id   = hcloud_load_balancer_service.https[0].id
    certificate_id     = var.ssl_certificate_type == "managed" ? hcloud_managed_certificate.main[0].id : "N/A"
    backend_protocol   = "HTTP"
    ssl_algorithms     = "TLS 1.2, TLS 1.3 (managed by Hetzner)"
    sticky_sessions    = var.enable_sticky_sessions ? "Enabled" : "Disabled"
    health_check_path  = "/health"
  } : {
    https_service_id   = "N/A"
    certificate_id     = "N/A"
    backend_protocol   = "N/A"
    ssl_algorithms     = "N/A"
    sticky_sessions    = "N/A"
    health_check_path  = "N/A"
  }
  description = "Load Balancer SSL termination service details"
}
