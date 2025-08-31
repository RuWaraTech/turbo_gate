# Hetzner Load Balancer Configuration with Correct Syntax

# Firewall for Load Balancer (conditional)
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
  }
}

# Create the Load Balancer (conditional)
resource "hcloud_load_balancer" "main" {
  count              = var.enable_load_balancer ? 1 : 0
  name               = "turbogate-lb-${var.environment}"
  load_balancer_type = var.load_balancer_type
  location           = var.location
  algorithm_type     = var.load_balancer_algorithm
  
  labels = {
    app         = "turbogate"
    environment = var.environment
    managed_by  = "terraform"
  }
  
  delete_protection = var.environment == "prod" ? true : false
}

# Attach Load Balancer to the private network (conditional)
resource "hcloud_load_balancer_network" "main" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = hcloud_load_balancer.main[0].id
  network_id       = hcloud_network.main.id
  ip               = "10.0.0.2"
  
  depends_on = [
    hcloud_network_subnet.main
  ]
}

# Target the manager node (conditional)
resource "hcloud_load_balancer_target" "manager" {
  count            = var.enable_load_balancer ? 1 : 0
  type             = "server"
  load_balancer_id = hcloud_load_balancer.main[0].id
  server_id        = hcloud_server.manager.id
  use_private_ip   = true
  
  depends_on = [
    hcloud_load_balancer_network.main
  ]
}

# Target worker nodes (conditional)
resource "hcloud_load_balancer_target" "workers" {
  count            = var.enable_load_balancer ? length(hcloud_server.worker) : 0
  type             = "server"
  load_balancer_id = hcloud_load_balancer.main[0].id
  server_id        = hcloud_server.worker[count.index].id
  use_private_ip   = true
  
  depends_on = [
    hcloud_load_balancer_network.main
  ]
}

# HTTP Service (redirects to HTTPS) (conditional)
resource "hcloud_load_balancer_service" "http" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = hcloud_load_balancer.main[0].id
  protocol         = "http"
  listen_port      = 80
  destination_port = 80
  
  health_check {
    protocol = "http"
    port     = 80
    interval = var.health_check_interval
    timeout  = var.health_check_timeout
    retries  = var.health_check_retries
    
    http {
      path         = "/lb-health"
      status_codes = ["200", "301", "302"]
      tls          = false
    }
  }
  
  http {
    sticky_sessions = var.enable_sticky_sessions
    redirect_http   = var.enable_ssl_redirect
    cookie_name     = var.enable_sticky_sessions ? "TURBOGATE_LB" : null
    cookie_lifetime = var.enable_sticky_sessions ? 3600 : null
  }
}

# HTTPS Service (main traffic) (conditional)
resource "hcloud_load_balancer_service" "https" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = hcloud_load_balancer.main[0].id
  protocol         = "https"
  listen_port      = 443
  destination_port = 80  # WAF listens on 80, LB handles SSL
  
  health_check {
    protocol = "http"
    port     = 80
    interval = var.health_check_interval
    timeout  = var.health_check_timeout
    retries  = var.health_check_retries
    
    http {
      path         = "/lb-health"
      status_codes = ["200"]
      tls          = false
    }
  }
  
  http {
    sticky_sessions = var.enable_sticky_sessions
    cookie_name     = var.enable_sticky_sessions ? "TURBOGATE_LB" : null
    cookie_lifetime = var.enable_sticky_sessions ? 3600 : null
    certificates    = var.enable_load_balancer ? [hcloud_managed_certificate.main[0].id] : []
  }
}

# Managed Certificate (conditional)
resource "hcloud_managed_certificate" "main" {
  count        = var.enable_load_balancer ? 1 : 0
  name         = "turbogate-cert-${var.environment}"
  domain_names = length(var.ssl_domains) > 0 ? var.ssl_domains : [var.domain_name, "www.${var.domain_name}"]
  
  labels = {
    app         = "turbogate"
    environment = var.environment
  }
  
  lifecycle {
    create_before_destroy = true
  }
}