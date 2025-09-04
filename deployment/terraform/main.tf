provider "hcloud" {
  token = var.hcloud_token
}

# SSH Key
resource "hcloud_ssh_key" "default" {
  name       = "turbogate-key"
  public_key = var.ssh_public_key
}

# Network
resource "hcloud_network" "main" {
  name     = "turbogate-network"
  ip_range = "10.0.0.0/16"
}

# Network Subnets
resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_network_subnet" "application" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"  
  ip_range     = "10.0.2.0/24"
}

resource "hcloud_network_subnet" "database" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.3.0/24"
}

resource "hcloud_network_subnet" "monitoring" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.4.0/24"
}

# Firewall for SSH Access
resource "hcloud_firewall" "ssh_access" {
  name = "turbogate-ssh-fw"
  
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.allowed_ssh_ips
    description = "SSH access from allowed IPs only"
  }

    # INTERNAL SSH access (for Ansible and management)
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["10.0.0.0/16"]  # Internal network
    description = "SSH access from internal network"
  }
  
  rule {
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["10.0.0.0/16"]
    description = "Internal ICMP"
  }
  
  labels = {
    purpose     = "ssh-security"
    environment = var.environment
  }
}

# Firewall for Traefik Proxy with ModSecurity WAF
resource "hcloud_firewall" "traefik" {
  name = "turbogate-traefik-fw"

  # Allow HTTP from Load Balancer only (via private network)
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["10.0.4.0/24"]  # Monitoring subnet (where LB is)
    description = "HTTP from Load Balancer to Traefik"
  }


  # Health check port for Traefik monitoring (consolidated rule)
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "8080"
    source_ips  = ["10.0.0.0/16"]
    description = "Traefik health checks from internal network and LB"
  }

  labels = {
    purpose     = "traefik-security"
    environment = var.environment
  }
}

# Firewall for internal application traffic
resource "hcloud_firewall" "internal_app" {
  name = "turbogate-internal-app-fw"

  # Allow traffic from Traefik containers
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "5000"
    source_ips  = ["10.0.0.0/16"]
    description = "App traffic from Traefik"
  }

  labels = {
    purpose     = "internal-app"
    environment = var.environment
  }
}

# Docker Swarm Firewall
resource "hcloud_firewall" "docker_swarm" {
  name = "turbogate-swarm-fw"
  
  # Docker Swarm manager API
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "2377"
    source_ips  = ["10.0.0.0/16"]
    description = "Docker Swarm manager API"
  }
  
  # Container network discovery TCP
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "7946"
    source_ips  = ["10.0.0.0/16"]
    description = "Container network discovery TCP"
  }
  
  # Container network discovery UDP
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "7946"
    source_ips  = ["10.0.0.0/16"]
    description = "Container network discovery UDP"
  }
  
  # Overlay network traffic (VXLAN)
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "4789"
    source_ips  = ["10.0.0.0/16"]
    description = "Overlay network VXLAN"
  }
  
  labels = {
    purpose     = "docker-swarm"
    environment = var.environment
  }
}

# Manager Node
resource "hcloud_server" "manager" {
  name        = "turbogate-manager"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  
  firewall_ids = [
    hcloud_firewall.ssh_access.id,
    hcloud_firewall.traefik.id,
    hcloud_firewall.internal_app.id,
    hcloud_firewall.docker_swarm.id
  ]
  
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.10"
  }
  
  user_data = templatefile("${path.module}/../scripts/node_init.sh", {
    node_type           = "manager"
    node_index          = 0
    manager_ip          = "10.0.1.10"
    worker_count        = var.worker_count
    fail2ban_config     = jsonencode(var.fail2ban_config)
    enable_hardening    = var.enable_security_hardening
    traefik_enabled     = var.traefik_enabled
  })
  
  labels = {
    role              = "manager"
    app               = "turbogate"
    environment       = var.environment
    security_hardened = var.enable_security_hardening ? "true" : "false"
    traefik_enabled   = var.traefik_enabled ? "true" : "false"
  }
}

# Worker Nodes - UPDATED with explicit dependencies
resource "hcloud_server" "worker" {
  count       = var.worker_count
  name        = "turbogate-worker-${count.index + 1}"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  
  firewall_ids = [
    hcloud_firewall.ssh_access.id,
    hcloud_firewall.traefik.id,
    hcloud_firewall.internal_app.id,
    hcloud_firewall.docker_swarm.id
  ]
  
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.2.${11 + count.index}"
  }
  
  user_data = templatefile("${path.module}/../scripts/node_init.sh", {
    node_type           = "worker"
    node_index          = count.index + 1
    manager_ip          = "10.0.1.10"
    worker_count        = var.worker_count
    fail2ban_config     = jsonencode(var.fail2ban_config)
    enable_hardening    = var.enable_security_hardening
    traefik_enabled     = var.traefik_enabled
  })
  
  labels = {
    role              = "worker"
    app               = "turbogate"
    environment       = var.environment
    security_hardened = var.enable_security_hardening ? "true" : "false"
    traefik_enabled   = var.traefik_enabled ? "true" : "false"
    worker_id         = count.index + 1
  }
  
  # ADDED: Explicit dependencies to prevent network attachment issues
  depends_on = [
    hcloud_network.main,
    hcloud_network_subnet.application,
    hcloud_firewall.ssh_access,
    hcloud_firewall.traefik,
    hcloud_firewall.internal_app,
    hcloud_firewall.docker_swarm
  ]
}

# Generate Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../ansible/inventory/inventory.tpl", {
    manager_ip       = hcloud_server.manager.ipv4_address
    manager_internal = "10.0.1.10"
    worker_ips       = [for s in hcloud_server.worker : s.ipv4_address]
    worker_internals = [for i in range(var.worker_count) : "10.0.2.${11 + i}"]
    worker_count     = var.worker_count
    
    enable_load_balancer = var.enable_load_balancer
    load_balancer_ip     = var.enable_load_balancer ? hcloud_load_balancer.main[0].ipv4 : ""
    load_balancer_ipv6   = var.enable_load_balancer ? hcloud_load_balancer.main[0].ipv6 : ""
    load_balancer_internal = var.enable_load_balancer ? "10.0.4.10" : ""
    
    # Traefik + ModSecurity WAF configuration
    traefik_enabled         = var.traefik_enabled
    modsec_rule_engine      = var.modsec_rule_engine
    modsec_paranoia_level   = var.modsec_paranoia_level
    modsec_replicas         = var.modsec_replicas
    traefik_dashboard_auth  = var.traefik_dashboard_auth
    rate_limit_average      = var.rate_limit_average
    rate_limit_burst        = var.rate_limit_burst
    
    # Traefik configuration
    traefik_deployment_mode = var.traefik_deployment_mode
    traefik_replicas        = var.traefik_replicas
    enable_proxy_protocol = var.enable_proxy_protocol
    
    # Security configuration
    security_enabled = var.enable_security_hardening
    fail2ban_enabled = var.enable_security_hardening
    fail2ban_bantime = var.fail2ban_config.bantime
    fail2ban_findtime = var.fail2ban_config.findtime
    fail2ban_maxretry = var.fail2ban_config.maxretry
    ssh_maxretry = var.fail2ban_config.ssh_maxretry
    
    # Network configuration
    network_subnets = {
      management  = "10.0.1.0/24"
      application = "10.0.2.0/24"
      database    = "10.0.3.0/24"
      monitoring  = "10.0.4.0/24"
    }
    
    # Docker Swarm configuration
    swarm_encryption_enabled = true
    swarm_networks = {
      frontend = {
        subnet = "172.20.0.0/24"
        encrypted = true
      }
      backend = {
        subnet = "172.20.1.0/24"
        encrypted = true
      }
      database = {
        subnet = "172.20.2.0/24"
        encrypted = true
      }
    }
  })
  
  filename = "${path.module}/../ansible/inventory/production.yml"
  
  depends_on = [
    hcloud_server.manager,
    hcloud_server.worker,
    hcloud_load_balancer.main,
    hcloud_load_balancer_network.main
  ]
}