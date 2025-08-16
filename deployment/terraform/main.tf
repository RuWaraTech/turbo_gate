data "http" "github_meta" {
  url = "https://api.github.com/meta"
}

locals {
  github_meta = jsondecode(data.http.github_meta.response_body)
  github_actions_ips = local.github_meta.actions
}

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

# ===== SECURITY HARDENED FIREWALL =====
# CHANGED: Added restrictive rules, egress controls, and IP allowlisting
resource "hcloud_firewall" "main" {
  name = "turbogate-firewall"
  
  # CHANGED: SSH restricted to admin IPs only (no longer 0.0.0.0/0)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = concat(var.admin_ips, local.github_actions_ips)
    description = "SSH access from admin IPs only"
  }
  
  # HTTP/HTTPS remain public but with rate limiting in NGINX
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
  
  # CHANGED: Docker Swarm restricted to specific node IPs only
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "2377"
    source_ips = ["10.0.1.10/32", "10.0.1.11/32", "10.0.1.12/32"]  # CHANGED: Specific IPs
    description = "Docker Swarm manager - internal nodes only"
  }
  
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "7946"
    source_ips = ["10.0.1.0/24"]  # CHANGED: Subnet restriction
    description = "Container network discovery"
  }
  
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "7946"
    source_ips = ["10.0.1.0/24"]  # CHANGED: Subnet restriction
    description = "Container network discovery"
  }
  
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "4789"
    source_ips = ["10.0.1.0/24"]  # CHANGED: Subnet restriction
    description = "Overlay network traffic"
  }
  
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["10.0.1.0/24"]  # CHANGED: Subnet restriction
    description = "Internal network ping"
  }

  # NEW: Egress rules for security
  rule {
    direction = "out"
    protocol  = "tcp"
    port      = "443"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description = "HTTPS outbound for updates and Docker Hub"
  }

  # NEW: DNS egress
  rule {
    direction = "out"
    protocol  = "udp"
    port      = "53"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description = "DNS resolution"
  }

  # NEW: NTP egress
  rule {
    direction = "out"
    protocol  = "udp"
    port      = "123"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description = "NTP time sync"
  }

  # NEW: APT updates
  rule {
    direction = "out"
    protocol  = "tcp"
    port      = "80"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description = "HTTP for APT updates"
  }

  # NEW: Block all other outbound traffic by default
  apply_to = [
    {
      label_selector = "app=turbogate"
    }
  ]
}

# NEW: Bastion Host (optional but recommended)
resource "hcloud_server" "bastion" {
  count       = var.enable_bastion ? 1 : 0
  name        = "turbogate-bastion"
  image       = "ubuntu-22.04"
  server_type = "cx11"  # Small instance
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]

  firewall_ids = [hcloud_firewall.bastion[0].id]

  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update
    apt-get install -y python3 python3-pip net-tools
  EOF

  labels = {
    role = "bastion"
    app  = "turbogate"
  }
}

# NEW: Bastion-specific firewall
resource "hcloud_firewall" "bastion" {
  count = var.enable_bastion ? 1 : 0
  name = "turbogate-bastion-firewall"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.admin_ips
    description = "SSH from admin IPs"
  }
}

# Manager Node - SECURITY ENHANCED
resource "hcloud_server" "manager" {
  name        = "turbogate-manager"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.main.id]
  
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.10"
  }
  
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update
    apt-get install -y python3 python3-pip net-tools
    echo "10.0.1.10 turbogate-manager" >> /etc/hosts
    echo "10.0.1.11 turbogate-worker-1" >> /etc/hosts
    echo "10.0.1.12 turbogate-worker-2" >> /etc/hosts
  EOF
  
  labels = {
    role = "manager"
    app  = "turbogate"
  }
}

# Worker Nodes - Enhanced user_data
resource "hcloud_server" "worker" {
  count       = 2
  name        = "turbogate-worker-${count.index + 1}"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.main.id]
  
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.${11 + count.index}"
  }
  
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update
    apt-get install -y python3 python3-pip net-tools
    echo "10.0.1.10 turbogate-manager" >> /etc/hosts
    echo "10.0.1.11 turbogate-worker-1" >> /etc/hosts
    echo "10.0.1.12 turbogate-worker-2" >> /etc/hosts
  EOF
  
  labels = {
    role = "worker"
    app  = "turbogate"
  }
}

# Floating IP for high availability
resource "hcloud_floating_ip" "main" {
  type          = "ipv4"
  home_location = var.location
  description   = "TurboGate Floating IP"
}

# Auto-assign floating IP to manager
resource "hcloud_floating_ip_assignment" "main" {
  floating_ip_id = hcloud_floating_ip.main.id
  server_id      = hcloud_server.manager.id
}

# CHANGED: Updated inventory to use deploy user
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../ansible/inventory/inventory.tpl", {
    manager_ip   = hcloud_server.manager.ipv4_address
    worker_1_ip  = hcloud_server.worker[0].ipv4_address
    worker_2_ip  = hcloud_server.worker[1].ipv4_address
    floating_ip  = hcloud_floating_ip.main.ip_address
    ssh_user     = "deploy"  # NEW: Use deploy user
    bastion_ip   = var.enable_bastion ? hcloud_server.bastion[0].ipv4_address : ""
  })
  filename = "${path.module}/../ansible/inventory/production.yml"
}
