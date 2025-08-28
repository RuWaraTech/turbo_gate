all:
  children:
    swarm_managers:
      hosts:
        turbogate-manager:
          ansible_host: "${manager_ip}"
          ansible_user: root
          internal_ip: ${manager_internal}
          
    workers:
      hosts:
        turbogate-worker-1:
          ansible_host: "${worker_1_ip}"
          ansible_user: root
          internal_ip: ${worker_1_internal}
          
        turbogate-worker-2:
          ansible_host: "${worker_2_ip}"
          ansible_user: root
          internal_ip: ${worker_2_internal}
          
  vars:
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    ansible_python_interpreter: /usr/bin/python3
    floating_ip: "${floating_ip}"
    
    # Security configuration
    security_enabled: ${security_enabled}
    fail2ban_enabled: ${fail2ban_enabled}
    
    # fail2ban settings
    fail2ban_bantime: ${fail2ban_bantime}
    fail2ban_findtime: ${fail2ban_findtime}
    fail2ban_maxretry: ${fail2ban_maxretry}
    ssh_maxretry: ${ssh_maxretry}
    
    # Network segmentation
    network_subnets:
      management: "${network_subnets.management}"
      application: "${network_subnets.application}"
      database: "${network_subnets.database}"
      monitoring: "${network_subnets.monitoring}"
    
    # Docker Swarm security
    swarm_encryption_enabled: ${swarm_encryption_enabled}
    swarm_networks:
      frontend:
        subnet: "${swarm_networks.frontend.subnet}"
        encrypted: ${swarm_networks.frontend.encrypted}
      backend:
        subnet: "${swarm_networks.backend.subnet}"
        encrypted: ${swarm_networks.backend.encrypted}
      database:
        subnet: "${swarm_networks.database.subnet}"
        encrypted: ${swarm_networks.database.encrypted}
    
    # Automatic updates configuration
    automatic_reboot: false
    reboot_time: "02:00"
    notification_email: "root"
    remove_unused_deps: true