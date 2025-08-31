#!/bin/bash
# SSL Certificate Synchronization Script for Global NGINX Deployment
# This script ensures all Docker Swarm nodes have the same SSL certificates

set -e

# Configuration
DOMAIN_NAME="${1:-ridebase.app}"
LETSENCRYPT_DIR="/etc/letsencrypt"
CERTBOT_WEBROOT="/var/www/certbot"
LOG_FILE="/var/log/ssl-sync.log"
MANAGER_NODE=$(docker node ls --filter role=manager --format '{{.Hostname}}' | head -1)

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if running on manager node
is_manager() {
    hostname | grep -q "$MANAGER_NODE"
}

# Function to sync certificates to a specific node
sync_to_node() {
    local NODE_NAME=$1
    local NODE_IP=$2
    
    log "Syncing certificates to $NODE_NAME ($NODE_IP)..."
    
    # Create temporary archive
    tar czf /tmp/letsencrypt-sync.tar.gz -C / etc/letsencrypt 2>/dev/null
    
    # Copy archive to worker
    scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        /tmp/letsencrypt-sync.tar.gz root@${NODE_IP}:/tmp/ || {
        log "ERROR: Failed to copy certificates to $NODE_NAME"
        return 1
    }
    
    # Extract on worker and verify
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@${NODE_IP} \
        "tar xzf /tmp/letsencrypt-sync.tar.gz -C / && \
         rm /tmp/letsencrypt-sync.tar.gz && \
         test -f ${LETSENCRYPT_DIR}/live/${DOMAIN_NAME}/fullchain.pem && \
         echo 'Certificates synced successfully'" || {
        log "ERROR: Failed to extract certificates on $NODE_NAME"
        return 1
    }
    
    log "✓ Successfully synced to $NODE_NAME"
    return 0
}

# Function to sync certificates to all nodes
sync_all_nodes() {
    log "Starting certificate synchronization to all nodes..."
    
    local FAILED_NODES=""
    local SUCCESS_COUNT=0
    local TOTAL_COUNT=0
    
    # Get all worker nodes
    while IFS= read -r line; do
        NODE_NAME=$(echo "$line" | awk '{print $1}')
        NODE_IP=$(echo "$line" | awk '{print $2}')
        
        if [ "$NODE_NAME" != "$(hostname)" ]; then
            ((TOTAL_COUNT++))
            if sync_to_node "$NODE_NAME" "$NODE_IP"; then
                ((SUCCESS_COUNT++))
            else
                FAILED_NODES="${FAILED_NODES} ${NODE_NAME}"
            fi
        fi
    done < <(docker node ls --format '{{.Hostname}} {{.Status}}' | grep Ready | awk '{print $1, $2}' | while read name status; do
        ip=$(docker node inspect "$name" --format '{{.Status.Addr}}' 2>/dev/null)
        echo "$name $ip"
    done)
    
    log "Synchronization complete: $SUCCESS_COUNT/$TOTAL_COUNT nodes successful"
    
    if [ -n "$FAILED_NODES" ]; then
        log "WARNING: Failed to sync to nodes:$FAILED_NODES"
        return 1
    fi
    
    return 0
}

# Function to verify certificates on all nodes
verify_all_nodes() {
    log "Verifying certificates on all nodes..."
    
    local ALL_GOOD=true
    
    docker node ls --format '{{.Hostname}}' | while read NODE_NAME; do
        if [ "$NODE_NAME" = "$(hostname)" ]; then
            # Local check
            if [ -f "${LETSENCRYPT_DIR}/live/${DOMAIN_NAME}/fullchain.pem" ]; then
                log "✓ $NODE_NAME: Certificate present (local)"
            else
                log "✗ $NODE_NAME: Certificate missing (local)"
                ALL_GOOD=false
            fi
        else
            # Remote check
            NODE_IP=$(docker node inspect "$NODE_NAME" --format '{{.Status.Addr}}')
            if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${NODE_IP} \
                "test -f ${LETSENCRYPT_DIR}/live/${DOMAIN_NAME}/fullchain.pem" 2>/dev/null; then
                log "✓ $NODE_NAME: Certificate present"
            else
                log "✗ $NODE_NAME: Certificate missing or unreachable"
                ALL_GOOD=false
            fi
        fi
    done
    
    if [ "$ALL_GOOD" = true ]; then
        log "All nodes have valid certificates"
        return 0
    else
        log "Some nodes are missing certificates"
        return 1
    fi
}

# Function to reload NGINX on all nodes
reload_nginx_global() {
    log "Reloading NGINX WAF service globally..."
    
    # Update the service to force reload on all nodes
    docker service update --force turbogate_nginx-waf 2>/dev/null || {
        log "WARNING: Could not reload NGINX WAF service"
        return 1
    }
    
    log "NGINX WAF service reload initiated"
    return 0
}

# Main execution
main() {
    log "=== SSL Certificate Sync Script Started ==="
    log "Domain: $DOMAIN_NAME"
    log "Running on: $(hostname)"
    
    # Check if this is the manager node
    if ! is_manager; then
        log "ERROR: This script must run on the manager node ($MANAGER_NODE)"
        exit 1
    fi
    
    # Check if certificates exist
    if [ ! -f "${LETSENCRYPT_DIR}/live/${DOMAIN_NAME}/fullchain.pem" ]; then
        log "ERROR: No certificates found for $DOMAIN_NAME"
        log "Please run certbot first to generate certificates"
        exit 1
    fi
    
    # Get certificate expiry
    CERT_EXPIRY=$(openssl x509 -enddate -noout -in "${LETSENCRYPT_DIR}/live/${DOMAIN_NAME}/fullchain.pem" | cut -d= -f2)
    log "Certificate expires: $CERT_EXPIRY"
    
    # Perform synchronization
    if sync_all_nodes; then
        log "Certificate synchronization successful"
    else
        log "WARNING: Some nodes failed to sync, continuing anyway..."
    fi
    
    # Verify all nodes
    sleep 5
    if verify_all_nodes; then
        log "Verification successful - all nodes have certificates"
        
        # Reload NGINX globally
        reload_nginx_global
    else
        log "ERROR: Verification failed - manual intervention required"
        exit 1
    fi
    
    log "=== SSL Certificate Sync Complete ==="
}

# Handle certificate renewal
if [ "$2" = "renew" ]; then
    log "Attempting certificate renewal..."
    
    # Run certbot renewal
    certbot renew --quiet --webroot -w "$CERTBOT_WEBROOT" || {
        log "Certificate renewal failed or not needed"
        exit 0
    }
    
    log "Certificates renewed successfully"
    
    # Sync to all nodes
    main
else
    # Just sync existing certificates
    main
fi