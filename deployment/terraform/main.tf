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

# Firewall - Enhanced for Docker Swarm
resource "hcloud_firewall" "main" {
  name = "turbogate-firewall"
  
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  
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
  
  # Docker Swarm ports - Enhanced rules
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "2377"
    source_ips = ["10.0.0.0/16"]
    description = "Docker Swarm manager API"
  }
  
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "7946"
    source_ips = ["10.0.0.0/16"]
    description = "Container network discovery"
  }
  
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "7946"
    source_ips = ["10.0.0.0/16"]
    description = "Container network discovery"
  }
  
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "4789"
    source_ips = ["10.0.0.0/16"]
    description = "Overlay network traffic"
  }
  
  # Additional rule for ICMP (ping)
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["10.0.0.0/16"]
    description = "Internal network ping"
  }
}

# Manager Node - Enhanced user_data for Docker Swarm
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

# Generate Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../ansible/inventory/inventory.tpl", {
    manager_ip   = hcloud_server.manager.ipv4_address
    worker_1_ip  = hcloud_server.worker[0].ipv4_address
    worker_2_ip  = hcloud_server.worker[1].ipv4_address
    floating_ip  = hcloud_floating_ip.main.ip_address
  })
  filename = "${path.module}/../ansible/inventory/production.yml"
}

# Output for debugging
output "all_network_ips" {
  value = {
    manager_public = hcloud_server.manager.ipv4_address
    manager_internal = [for net in hcloud_server.manager.network : net.ip][0]
    workers_public = [for s in hcloud_server.worker : s.ipv4_address]
    workers_internal = [for s in hcloud_server.worker : [for net in s.network : net.ip][0]]
  }
  description = "All network IPs for verification"
}