# Hetzner Load Balancer Configuration with PROXY Protocol Support

# Firewall for Load Balancer
resource "hcloud_firewall" "load_balancer" {
  count = var.enable_load_balancer ? 1 : 0
  name  = "turbogate-lb-fw-${var.environment}"
  
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  
  labels = {
    purpose     = "load-balancer"
    environment = var.environment
    waf_enabled = var.waf_enabled ? "true" : "false"
  }
}

# Create the Load Balancer
resource "hcloud_load_balancer" "main" {
  count              = var.enable_load_balancer ? 1 : 0
  name               = "turbogate-lb-${var.environment}"
  load_balancer_type = var.load_balancer_type
  location           = var.location
  
  algorithm {
    type = var.load_balancer_algorithm
  }
  
  labels = {
    app         = "turbogate"
    environment = var.environment
    managed_by  = "terraform"
    waf_enabled = var.waf_enabled ? "true" : "false"
  }
  
  delete_protection = var.environment == "prod" ? true : false
}

# Attach Load Balancer to the private network
resource "hcloud_load_balancer_network" "main" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = hcloud_load_balancer.main[0].id
  network_id       = hcloud_network.main.id
  ip               = "10.0.4.10"  # Fixed IP in monitoring subnet
  
  depends_on = [
    hcloud_network_subnet.monitoring
  ]
}

# Target all nodes for NGINX global deployment
resource "hcloud_load_balancer_target" "all_nodes" {
  count            = var.enable_load_balancer ? (1 + var.worker_count) : 0
  type             = "server"
  load_balancer_id = hcloud_load_balancer.main[0].id
  server_id        = count.index == 0 ? hcloud_server.manager.id : hcloud_server.worker[count.index - 1].id
  use_private_ip   = true
  
  depends_on = [
    hcloud_load_balancer_network.main
  ]
}

# HTTP Service (redirects to HTTPS)
resource "hcloud_load_balancer_service" "http" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = hcloud_load_balancer.main[0].id
  protocol         = "tcp"  # TCP for PROXY protocol
  listen_port      = 80
  destination_port = 80
  proxyprotocol    = var.enable_proxy_protocol
  
  health_check {
    protocol = "tcp"  # CHANGED: TCP health check for TCP service
    port     = 80
    interval = var.health_check_interval
    timeout  = var.health_check_timeout
    retries  = var.health_check_retries
    # REMOVED: http block (not compatible with TCP protocol)
  }
}

# HTTPS Service (main traffic with PROXY protocol)
resource "hcloud_load_balancer_service" "https" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = hcloud_load_balancer.main[0].id
  protocol         = "tcp"  # TCP for PROXY protocol
  listen_port      = 443
  destination_port = 443
  proxyprotocol    = var.enable_proxy_protocol
  
  health_check {
    protocol = "tcp"  # CHANGED: TCP health check for TCP service
    port     = 443
    interval = var.health_check_interval
    timeout  = var.health_check_timeout
    retries  = var.health_check_retries
    # REMOVED: http block (not compatible with TCP protocol)
  }
}

# Managed Certificate with unique name
resource "hcloud_managed_certificate" "main" {
  count        = var.enable_load_balancer && var.ssl_certificate_type == "managed" ? 1 : 0
  name         = "turbogate-cert-${var.environment}-${formatdate("YYYYMMDD-HHmm", timestamp())}"  # CHANGED: Added timestamp for uniqueness
  domain_names = length(var.ssl_domains) > 0 ? var.ssl_domains : [var.domain_name, "www.${var.domain_name}"]
  
  labels = {
    app         = "turbogate"
    environment = var.environment
  }
  
  lifecycle {
    create_before_destroy = true
    ignore_changes = [name]  # ADDED: Prevent recreation on timestamp changes
  }
}

# Note: Since we're using TCP mode with PROXY protocol,
# SSL termination happens at NGINX, not at the load balancer.
# The certificate resource above is for reference/future use.