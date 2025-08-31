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

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

# Additional network subnets for security segmentation
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

# Enhanced firewalls with granular rules
resource "hcloud_firewall" "ssh_access" {
  name = "turbogate-ssh-fw"
  
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.allowed_ssh_ips
    description = "SSH access from allowed IPs only"
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

resource "hcloud_firewall" "internal_web" {
  name = "turbogate-internal-web-fw"

  # Only allow HTTP/HTTPS from Load Balancer and internal networks
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["10.0.0.0/16"]  # Internal network only (includes LB)
    description = "HTTP from internal network and LB"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["10.0.0.0/16"]
    description = "HTTPS from internal network"
  }

  labels = {
    purpose     = "internal-web-access"
    environment = var.environment
  }
}

resource "hcloud_firewall" "docker_swarm_enhanced" {
  name = "turbogate-swarm-enhanced-fw"
  
  # Docker Swarm manager API - more restrictive
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "2377"
    source_ips  = ["10.0.1.0/24", "10.0.2.0/24"]  # Only management and app subnets
    description = "Docker Swarm manager API - restricted"
  }
  
  # Container network discovery TCP
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "7946"
    source_ips  = ["10.0.1.0/24", "10.0.2.0/24"]
    description = "Container network discovery TCP"
  }
  
  # Container network discovery UDP
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "7946"
    source_ips  = ["10.0.1.0/24", "10.0.2.0/24"]
    description = "Container network discovery UDP"
  }
  
  # Overlay network traffic (VXLAN)
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "4789"
    source_ips  = ["10.0.1.0/24", "10.0.2.0/24"]
    description = "Overlay network VXLAN"
  }
  
  labels = {
    purpose     = "docker-swarm-enhanced"
    environment = var.environment
  }
}

# Manager Node - Enhanced with multiple firewalls
resource "hcloud_server" "manager" {
  name        = "turbogate-manager"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  
  # Apply multiple firewalls for layered security
  firewall_ids = concat(
    [
      hcloud_firewall.internal_web.id,
      hcloud_firewall.ssh_access.id,
      hcloud_firewall.docker_swarm_enhanced.id
    ],
    var.enable_load_balancer ? [hcloud_firewall.load_balancer[0].id] : []
  )
  
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.10"
  }
  
  # Enhanced user_data with security hardening hooks
  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y python3 python3-pip net-tools curl
    
    # Basic security hardening
    echo "10.0.1.10 turbogate-manager" >> /etc/hosts
    %{for i in range(var.worker_count)}
    echo "10.0.2.${11 + i} turbogate-worker-${i + 1}" >> /etc/hosts
    %{endfor}
    
    # SSH hardening
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd
    
    # Install fail2ban
    apt-get install -y fail2ban
    systemctl enable fail2ban
    
    # Basic fail2ban config
    cat > /etc/fail2ban/jail.local << 'EOL'
[DEFAULT]
bantime = ${var.fail2ban_config.bantime}
findtime = ${var.fail2ban_config.findtime}
maxretry = ${var.fail2ban_config.maxretry}

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = ${var.fail2ban_config.ssh_maxretry}
EOL
    systemctl start fail2ban
    
    # Create marker file for Ansible to detect hardening status
    touch /tmp/security-hardening-started
  EOF
  
  labels = {
    role        = "manager"
    app         = "turbogate"
    environment = var.environment
    security_hardened = var.enable_security_hardening
  }
}

# Worker Nodes - Enhanced with security
resource "hcloud_server" "worker" {
  count       = var.worker_count
  name        = "turbogate-worker-${count.index + 1}"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  
  # Workers have more restrictive firewall setup (no direct web access)
  firewall_ids = concat(
    [
      hcloud_firewall.ssh_access.id,
      hcloud_firewall.internal_web.id,
      hcloud_firewall.docker_swarm_enhanced.id
    ],
    var.enable_load_balancer ? [hcloud_firewall.load_balancer[0].id] : []
  )
  
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.2.${11 + count.index}"
  }
  
  # Similar security hardening for workers
  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y python3 python3-pip net-tools curl
    
    echo "10.0.1.10 turbogate-manager" >> /etc/hosts
    %{for i in range(var.worker_count)}
    echo "10.0.2.${11 + i} turbogate-worker-${i + 1}" >> /etc/hosts
    %{endfor}
    
    # SSH hardening
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd
    
    # Install fail2ban
    apt-get install -y fail2ban
    systemctl enable fail2ban
    
    # Basic fail2ban config (worker version)
    cat > /etc/fail2ban/jail.local << 'EOL'
[DEFAULT]
bantime = ${var.fail2ban_config.bantime}
findtime = ${var.fail2ban_config.findtime}
maxretry = ${var.fail2ban_config.maxretry}

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = ${var.fail2ban_config.ssh_maxretry}
EOL
    systemctl start fail2ban
    
    touch /tmp/security-hardening-started
  EOF
  
  labels = {
    role        = "worker"
    app         = "turbogate"
    environment = var.environment
    security_hardened = var.enable_security_hardening
    worker_id   = count.index + 1
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../ansible/inventory/inventory.tpl", {
    manager_ip       = hcloud_server.manager.ipv4_address
    manager_internal = one([for network in hcloud_server.manager.network : network.ip if network.network_id == hcloud_network.main.id])
    worker_ips       = [for s in hcloud_server.worker : s.ipv4_address]
    worker_internals = [for s in hcloud_server.worker : one([for network in s.network : network.ip if network.network_id == hcloud_network.main.id])]
    worker_count     = var.worker_count
    
    enable_load_balancer = var.enable_load_balancer

    # Load Balancer configuration
    load_balancer_ip = var.enable_load_balancer ? hcloud_load_balancer.main[0].ipv4 : ""
    load_balancer_ipv6 = var.enable_load_balancer ? hcloud_load_balancer.main[0].ipv6 : ""
    load_balancer_internal = "10.0.0.2"
    
    # WAF configuration
    waf_enabled = var.waf_enabled
    waf_paranoia_level = var.waf_paranoia_level
    waf_anomaly_inbound = var.waf_anomaly_inbound
    waf_anomaly_outbound = var.waf_anomaly_outbound
    
    # Existing security configuration
    security_enabled = var.enable_security_hardening
    fail2ban_enabled = var.enable_security_hardening
    fail2ban_bantime = var.fail2ban_config.bantime
    fail2ban_findtime = var.fail2ban_config.findtime
    fail2ban_maxretry = var.fail2ban_config.maxretry
    ssh_maxretry = var.fail2ban_config.ssh_maxretry
    
    # Network configuration
    network_subnets = {
      management   = "10.0.1.0/24"
      application  = "10.0.2.0/24"
      database     = "10.0.3.0/24"
      monitoring   = "10.0.4.0/24"
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
    hcloud_load_balancer.main
  ]
}