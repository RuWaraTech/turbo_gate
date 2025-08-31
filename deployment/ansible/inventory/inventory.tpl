all:
  children:
    swarm_managers:
      hosts:
        turbogate-manager:
          ansible_host: ${manager_ip}
          ansible_user: root
          internal_ip: ${manager_internal}
          
    swarm_workers:
      hosts:
        %{ for i, ip in worker_ips ~}
        turbogate-worker-${i + 1}:
          ansible_host: ${ip}
          ansible_user: root
          internal_ip: ${worker_internals[i]}
        %{ endfor ~}
        
    %{ if enable_load_balancer ~}
    load_balancer:
      hosts:
        turbogate-lb:
          ansible_host: ${load_balancer_ip}
          ansible_user: root
          internal_ip: ${load_balancer_internal}
          ipv6_address: ${load_balancer_ipv6}
    %{ endif ~}
      
  vars:
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    ansible_python_interpreter: '/usr/bin/python3'
    
    # Load Balancer configuration
    load_balancer_enabled: ${enable_load_balancer}
    %{ if enable_load_balancer ~}
    load_balancer_ip: ${load_balancer_ip}
    load_balancer_ipv6: ${load_balancer_ipv6}
    %{ else ~}
    load_balancer_ip: ""
    load_balancer_ipv6: ""
    %{ endif ~}
    
    # WAF configuration
    waf_enabled: ${waf_enabled}
    waf_paranoia_level: ${waf_paranoia_level}
    waf_anomaly_inbound: ${waf_anomaly_inbound}
    waf_anomaly_outbound: ${waf_anomaly_outbound}
    
    # Security configuration
    security_enabled: ${security_enabled}
    fail2ban_enabled: ${fail2ban_enabled}
    
    # fail2ban settings
    fail2ban_bantime: "${fail2ban_bantime}"
    fail2ban_findtime: "${fail2ban_findtime}"
    fail2ban_maxretry: ${fail2ban_maxretry}
    ssh_maxretry: ${ssh_maxretry}
    
    # Network segmentation
    network_subnets:
      management: "${network_subnets["management"]}"
      application: "${network_subnets["application"]}"
      database: "${network_subnets["database"]}"
      monitoring: "${network_subnets["monitoring"]}"
    
    # Docker Swarm security
    swarm_encryption_enabled: ${swarm_encryption_enabled}
    swarm_networks:
      frontend:
        subnet: "${swarm_networks["frontend"]["subnet"]}"
        encrypted: ${swarm_networks["frontend"]["encrypted"]}
      backend:
        subnet: "${swarm_networks["backend"]["subnet"]}"
        encrypted: ${swarm_networks["backend"]["encrypted"]}
      database:
        subnet: "${swarm_networks["database"]["subnet"]}"
        encrypted: ${swarm_networks["database"]["encrypted"]}
    
    # Automatic updates configuration
    automatic_reboot: false
    reboot_time: "02:00"
    notification_email: "root"
    remove_unused_deps: true