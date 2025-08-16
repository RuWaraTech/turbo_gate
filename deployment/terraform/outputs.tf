output "all_network_ips" {
  value = {
    manager_public = hcloud_server.manager.ipv4_address
    manager_internal = [for net in hcloud_server.manager.network : net.ip][0]
    workers_public = [for s in hcloud_server.worker : s.ipv4_address]
    workers_internal = [for s in hcloud_server.worker : [for net in s.network : net.ip][0]]
    bastion_public = var.enable_bastion ? hcloud_server.bastion[0].ipv4_address : null
  }
  description = "All network IPs for verification"
  sensitive = true  # NEW: Mark as sensitive
}

output "floating_ip" {
  value = hcloud_floating_ip.main.ip_address
}

output "inventory_file_path" {
  value = local_file.ansible_inventory.filename
  description = "Path to the generated Ansible inventory file"
}