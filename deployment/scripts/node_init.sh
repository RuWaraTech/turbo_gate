#!/bin/bash
# Node initialization script - SSH Hardening & Host Security Only
set -e

# Variables passed from Terraform
NODE_TYPE="${node_type}"
NODE_INDEX="${node_index}"
MANAGER_IP="${manager_ip}"
WORKER_COUNT="${worker_count}"
ENABLE_HARDENING="${enable_hardening}"

# Extract fail2ban config values from the JSON-like string using jq
FAIL2BAN_CONFIG_JSON='${fail2ban_config}'
FAIL2BAN_BANTIME=$(echo "$FAIL2BAN_CONFIG_JSON" | jq -r '.bantime')
FAIL2BAN_FINDTIME=$(echo "$FAIL2BAN_CONFIG_JSON" | jq -r '.findtime')
FAIL2BAN_MAXRETRY=$(echo "$FAIL2BAN_CONFIG_JSON" | jq -r '.maxretry')
FAIL2BAN_SSH_MAXRETRY=$(echo "$FAIL2BAN_CONFIG_JSON" | jq -r '.ssh_maxretry')

# Update and install base packages
apt-get update
apt-get install -y python3 python3-pip net-tools curl jq

# Configure hosts file for internal DNS
echo "$MANAGER_IP turbogate-manager" >> /etc/hosts
for i in $(seq 1 $WORKER_COUNT); do
    echo "10.0.2.$((10 + i)) turbogate-worker-$i" >> /etc/hosts
done

# SSH hardening - THIS IS THE CORE SECURITY
if [[ "$ENABLE_HARDENING" == "true" ]]; then
    echo "Applying SSH security hardening..."
    
    # SSH configuration - Prevent brute force and unauthorized access
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
    sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
    sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 300/' /etc/ssh/sshd_config
    sed -i 's/^#*ClientAliveCountMax.*/ClientAliveCountMax 2/' /etc/ssh/sshd_config
    
    # Restart SSH to apply changes
    systemctl restart sshd
    echo "SSH hardening completed successfully"
    
    # Install and configure fail2ban - FOR SSH PROTECTION ONLY
    echo "Installing fail2ban for SSH protection..."
    apt-get install -y fail2ban
    
    # Configure fail2ban with SSH protection only
    cat > /etc/fail2ban/jail.local << EOL
[DEFAULT]
# Global fail2ban settings
bantime = $FAIL2BAN_BANTIME
findtime = $FAIL2BAN_FINDTIME
maxretry = $FAIL2BAN_MAXRETRY
destemail = root@localhost
action = %(action_mwl)s

[sshd]
# SSH protection - this is what we care about
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = $FAIL2BAN_SSH_MAXRETRY
bantime = $FAIL2BAN_BANTIME
findtime = $FAIL2BAN_FINDTIME

[sshd-ddos]
# Additional SSH protection against DDoS
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = $FAIL2BAN_SSH_MAXRETRY
EOL
    
    # Enable and start fail2ban service
    systemctl enable fail2ban
    systemctl start fail2ban
    
    # Verify fail2ban is working for SSH
    echo "Fail2Ban SSH protection status:"
    if fail2ban-client status sshd >/dev/null 2>&1; then
        echo "✅ Fail2Ban SSH protection is ACTIVE"
        fail2ban-client status sshd | grep -E "(Status|Currently banned)"
    else
        echo "❌ Fail2Ban SSH protection failed to start"
        systemctl status fail2ban --no-pager -l
        exit 1
    fi
fi

# Kernel hardening - Host-level security
if [[ "$ENABLE_HARDENING" == "true" ]]; then
    echo "Applying kernel-level security hardening..."
    
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

# Enable TCP/IP SYN cookies (DDoS protection)
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# IP forwarding for Docker (required)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOL
    
    # Apply kernel settings
    sysctl -p
    echo "Kernel hardening completed successfully"
fi

# Create marker file for Ansible
touch /tmp/security-hardening-started
echo "NODE_TYPE=$NODE_TYPE" > /tmp/node-info
echo "SECURITY_HARDENING=$ENABLE_HARDENING" >> /tmp/node-info

# Log initialization complete
echo "=========================================="
echo "Node initialization completed successfully"
echo "Type: $NODE_TYPE, Index: $NODE_INDEX"
echo "SSH Hardening: $ENABLE_HARDENING"
echo "Fail2Ban Protection: $ENABLE_HARDENING"
echo "=========================================="