output "manager_ip" {
  value = hcloud_server.manager.ipv4_address
}

output "floating_ip" {
  value = hcloud_floating_ip.main.ip_address
}

output "worker_ips" {
  value = [for s in hcloud_server.worker : s.ipv4_address]
}

output "internal_network" {
  value = {
    manager = hcloud_server.manager.network[0].ip
    workers = hcloud_server.worker[*].network[0].ip
  }
  description = "Internal network IPs"
}

output "inventory_file_path" {
  value = local_file.ansible_inventory.filename
  description = "Path to the generated Ansible inventory file"
}