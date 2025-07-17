output "manager_ip" {
  value = hcloud_server.manager.ipv4_address
}

output "floating_ip" {
  value = hcloud_floating_ip.main.ip_address
}

output "worker_ips" {
  value = [for s in hcloud_server.worker : s.ipv4_address]
}