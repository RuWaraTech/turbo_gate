#!/bin/bash
# Node initialization script with WAF preparation
set -e

# Variables passed from Terraform
NODE_TYPE="${node_type}"
NODE_INDEX="${node_index}"
MANAGER_IP="${manager_ip}"
WORKER_COUNT="${worker_count}"
ENABLE_HARDENING="${enable_hardening}"
WAF_ENABLED="${waf_enabled}"

# Update and install base packages
apt-get update
apt-get install -y python3 python3-pip net-tools curl jq

# Configure hosts file
echo "$MANAGER_IP turbogate-manager" >> /etc/hosts
for i in $(seq 1 $WORKER_COUNT); do
    echo "10.0.2.$((10 + i)) turbogate-worker-$i" >> /etc/hosts
done

# SSH hardening
if [[ "$ENABLE_HARDENING" == "true" ]]; then
    # SSH configuration
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
    sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
    sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 300/' /etc/ssh/sshd_config
    sed -i 's/^#*ClientAliveCountMax.*/ClientAliveCountMax 2/' /etc/ssh/sshd_config
    systemctl restart sshd
    
    # Install and configure fail2ban
    apt-get install -y fail2ban
    systemctl enable fail2ban
    
    # Configure fail2ban
    cat > /etc/fail2ban/jail.local << 'EOL'
[DEFAULT]
bantime = ${fail2ban_config.bantime}
findtime = ${fail2ban_config.findtime}
maxretry = ${fail2ban_config.maxretry}
destemail = root@localhost
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = ${fail2ban_config.ssh_maxretry}

# WAF jail if enabled
[nginx-waf]
enabled = ${waf_enabled}
port = http,https
filter = nginx-waf
logpath = /var/log/nginx/modsec_audit.log
maxretry = 3
bantime = 3600
findtime = 600
EOL

    # Create WAF filter for fail2ban if WAF is enabled
    if [[ "$WAF_ENABLED" == "true" ]]; then
        cat > /etc/fail2ban/filter.d/nginx-waf.conf << 'EOL'
[Definition]
failregex = ModSecurity: Access denied .* client: <HOST>
            ModSecurity: Warning .* \[client <HOST>\]
ignoreregex =
EOL
    fi
    
    systemctl start fail2ban
fi

# Kernel hardening
if [[ "$ENABLE_HARDENING" == "true" ]]; then
    cat >> /etc/sysctl.conf << 'EOL'
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore Directed pings
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable TCP/IP SYN cookies
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# IP forwarding for Docker
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOL
    sysctl -p
fi

# Prepare directories for WAF if enabled
if [[ "$WAF_ENABLED" == "true" ]]; then
    mkdir -p /var/log/nginx/waf
    mkdir -p /etc/nginx/modsecurity
    mkdir -p /var/cache/nginx
    chmod 755 /var/log/nginx/waf
fi

# Create marker file for Ansible
touch /tmp/security-hardening-started
echo "NODE_TYPE=$NODE_TYPE" > /tmp/node-info
echo "WAF_ENABLED=$WAF_ENABLED" >> /tmp/node-info

# Log initialization complete
echo "Node initialization completed - Type: $NODE_TYPE, Index: $NODE_INDEX, WAF: $WAF_ENABLED"