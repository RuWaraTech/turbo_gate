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

# Firewall
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
  
  # Docker Swarm ports - Internal only
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "2377"
    source_ips = ["10.0.0.0/16"]
  }
  
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "7946"
    source_ips = ["10.0.0.0/16"]
  }
  
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "7946"
    source_ips = ["10.0.0.0/16"]
  }
  
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "4789"
    source_ips = ["10.0.0.0/16"]
  }
}

# Manager Node
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
    apt-get install -y python3 python3-pip
  EOF
  
  labels = {
    role = "manager"
    app  = "turbogate"
  }
}

# Worker Nodes
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
    apt-get install -y python3 python3-pip
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
  # Note: firewall_ids is not a valid argument for floating IPs
}

# Auto-assign floating IP to manager
resource "hcloud_floating_ip_assignment" "main" {
  floating_ip_id = hcloud_floating_ip.main.id
  server_id      = hcloud_server.manager.id
}
