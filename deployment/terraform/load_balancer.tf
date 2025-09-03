# Hetzner Managed Certificate
resource "hcloud_managed_certificate" "main" {
  count        = var.enable_load_balancer && var.ssl_certificate_type == "managed" ? 1 : 0
  name         = "turbogate-cert-${var.environment}"
  domain_names = [var.domain_name, "www.${var.domain_name}"]

  labels = {
    app         = "turbogate"
    environment = var.environment
    managed_by  = "terraform"
  }
}

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
    waf_type    = "traefik-modsecurity"
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
    app             = "turbogate"
    environment     = var.environment
    managed_by      = "terraform"
    ssl_termination = "enabled"
  }

  delete_protection = var.environment == "prod" ? true : false
}

# Attach Load Balancer to the private network
resource "hcloud_load_balancer_network" "main" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = hcloud_load_balancer.main[0].id
  network_id       = hcloud_network.main.id
  ip               = "10.0.4.10"

  depends_on = [
    hcloud_network_subnet.monitoring
  ]
}

# Target all nodes for direct HTTP backend communication
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

# REMOVED: The http_redirect service is not needed.

# HTTPS Service with SSL termination at LB
resource "hcloud_load_balancer_service" "https" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = hcloud_load_balancer.main[0].id
  protocol         = "https"
  listen_port      = 443
  destination_port = 80  # Traefik HTTP port (LB handles TLS termination)

  http {
    certificates    = var.ssl_certificate_type == "managed" ? [hcloud_managed_certificate.main[0].id] : []
    sticky_sessions = var.enable_sticky_sessions
    cookie_name     = "HCLBSTICKY"
    cookie_lifetime = 3600
    # CORRECTED: This attribute on the HTTPS service handles the redirect.
    redirect_http   = true
  }

  proxyprotocol = true # Forward client connection details to backend

  health_check {
    protocol = "http"
    port     = 80
    interval = var.health_check_interval
    timeout  = var.health_check_timeout
    retries  = var.health_check_retries

    http {
      path = "/lb-health"
    }
  }
}

