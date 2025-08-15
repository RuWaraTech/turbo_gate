#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DEPLOYMENT_DIR="deployment"
TERRAFORM_DIR="${DEPLOYMENT_DIR}/terraform"
ANSIBLE_DIR="${DEPLOYMENT_DIR}/ansible"
SSH_KEY_PATH="${HOME}/.ssh/turbogate_rsa"
SSH_CONFIG_PATH="${HOME}/.ssh/config"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    command -v terraform >/dev/null 2>&1 || log_error "Terraform is not installed"
    command -v ansible >/dev/null 2>&1 || log_error "Ansible is not installed"
    command -v docker >/dev/null 2>&1 || log_error "Docker is not installed"
    command -v jq >/dev/null 2>&1 || log_error "jq is not installed"
    
    log_success "All prerequisites met"
}

# Generate or verify SSH keys
setup_ssh_keys() {
    log_info "Setting up SSH keys..."
    
    if [ -f "${SSH_KEY_PATH}" ]; then
        log_warning "SSH key already exists at ${SSH_KEY_PATH}"
        read -p "Do you want to use the existing key? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Backing up existing key..."
            mv "${SSH_KEY_PATH}" "${SSH_KEY_PATH}.backup.$(date +%s)"
            mv "${SSH_KEY_PATH}.pub" "${SSH_KEY_PATH}.pub.backup.$(date +%s)"
            generate_ssh_key
        fi
    else
        generate_ssh_key
    fi
    
    # Export the public key
    export SSH_PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")
    log_success "SSH public key loaded"
}

# Generate new SSH key
generate_ssh_key() {
    log_info "Generating new SSH key pair..."
    
    ssh-keygen -t rsa -b 4096 -f "${SSH_KEY_PATH}" -N "" -C "turbogate-deployment"
    
    # Set proper permissions
    chmod 600 "${SSH_KEY_PATH}"
    chmod 644 "${SSH_KEY_PATH}.pub"
    
    log_success "SSH key pair generated at ${SSH_KEY_PATH}"
}

# Configure SSH for easier access
configure_ssh() {
    log_info "Configuring SSH..."
    
    # Add SSH key to agent
    if [ -z "${SSH_AUTH_SOCK:-}" ]; then
        log_info "Starting SSH agent..."
        eval "$(ssh-agent -s)"
    fi
    
    ssh-add "${SSH_KEY_PATH}" 2>/dev/null || true
    
    # Create SSH config entry
    if ! grep -q "Host turbogate-manager" "${SSH_CONFIG_PATH}" 2>/dev/null; then
        log_info "Adding SSH config entry..."
        cat >> "${SSH_CONFIG_PATH}" <<EOF

# TurboGate Deployment
Host turbogate-manager
    HostName ${MANAGER_IP:-PENDING}
    User root
    IdentityFile ${SSH_KEY_PATH}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    fi
    
    log_success "SSH configured"
}

# Load environment variables
load_environment() {
    log_info "Loading environment variables..."
    
    if [ -f .env ]; then
        # Export all variables from .env file
        set -a
        source .env
        set +a
        log_success "Environment variables loaded from .env"
    else
        log_error ".env file not found. Please create it from .env.example"
    fi
    
    # Validate required variables
    local required_vars=(
        "HCLOUD_TOKEN"
        "DOMAIN_NAME"
        "ADMIN_EMAIL"
        "SECRET_KEY"
        "REDIS_PASSWORD"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Required environment variable $var is not set"
        fi
    done
}

# Terraform deployment
deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd "${TERRAFORM_DIR}"
    
    # Create terraform.tfvars from environment
    cat > terraform.tfvars <<EOF
hcloud_token   = "${HCLOUD_TOKEN}"
ssh_public_key = "${SSH_PUBLIC_KEY}"
domain_name    = "${DOMAIN_NAME}"
server_type    = "${SERVER_TYPE:-cx11}"
location       = "${LOCATION:-nbg1}"
EOF
    
    # Initialize Terraform
    if [ ! -d .terraform ]; then
        terraform init
    fi
    
    # Plan deployment
    terraform plan -out=tfplan
    
    # Apply deployment
    terraform apply tfplan
    
    # Get outputs
    MANAGER_IP=$(terraform output -raw manager_ip)
    FLOATING_IP=$(terraform output -raw floating_ip)
    
    # Update SSH config with actual IP
    sed -i.bak "s/HostName PENDING/HostName ${MANAGER_IP}/" "${SSH_CONFIG_PATH}"
    
    cd - > /dev/null
    
    log_success "Infrastructure deployed successfully"
    log_info "Manager IP: ${MANAGER_IP}"
    log_info "Floating IP: ${FLOATING_IP}"
}

# Update Ansible inventory
update_inventory() {
    log_info "Updating Ansible inventory..."
    
    # Create dynamic inventory script
    cat > "${ANSIBLE_DIR}/inventory/dynamic_inventory.py" <<'EOF'
#!/usr/bin/env python3
import json
import subprocess

def get_terraform_output():
    cmd = ["terraform", "output", "-json"]
    result = subprocess.run(cmd, capture_output=True, text=True, cwd="../terraform")
    return json.loads(result.stdout)

def main():
    outputs = get_terraform_output()
    
    inventory = {
        "_meta": {
            "hostvars": {}
        },
        "all": {
            "children": ["swarm_managers", "swarm_workers"]
        },
        "swarm_managers": {
            "hosts": ["manager"],
            "vars": {
                "ansible_user": "root",
                "ansible_ssh_private_key_file": "~/.ssh/turbogate_rsa"
            }
        },
        "swarm_workers": {
            "hosts": [],
            "vars": {
                "ansible_user": "root",
                "ansible_ssh_private_key_file": "~/.ssh/turbogate_rsa"
            }
        }
    }
    
    # Manager host
    inventory["_meta"]["hostvars"]["manager"] = {
        "ansible_host": outputs["manager_ip"]["value"],
        "swarm_role": "manager"
    }
    
    # Worker hosts (if any)
    if "worker_ips" in outputs and outputs["worker_ips"]["value"]:
        for idx, ip in enumerate(outputs["worker_ips"]["value"]):
            worker_name = f"worker{idx + 1}"
            inventory["swarm_workers"]["hosts"].append(worker_name)
            inventory["_meta"]["hostvars"][worker_name] = {
                "ansible_host": ip,
                "swarm_role": "worker"
            }
    
    print(json.dumps(inventory, indent=2))

if __name__ == "__main__":
    main()
EOF
    
    chmod +x "${ANSIBLE_DIR}/inventory/dynamic_inventory.py"
    
    log_success "Dynamic inventory created"
}

# Wait for servers to be ready
wait_for_servers() {
    log_info "Waiting for servers to be ready..."
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${MANAGER_IP}" exit 2>/dev/null; then
            log_success "Server is ready"
            return 0
        fi
        
        attempt=$((attempt + 1))
        log_info "Waiting for server... (attempt $attempt/$max_attempts)"
        sleep 10
    done
    
    log_error "Server failed to become ready"
}

# Deploy with Ansible
deploy_application() {
    log_info "Deploying application with Ansible..."
    
    cd "${ANSIBLE_DIR}"
    
    # Set Ansible options
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3
    
    # Common ansible arguments
    ANSIBLE_ARGS="-i inventory/dynamic_inventory.py"
    
    # Install Python on remote hosts (required for Ansible)
    log_info "Preparing remote hosts..."
    ansible all ${ANSIBLE_ARGS} -m raw -a "apt-get update && apt-get install -y python3 python3-pip"
    
    # Setup Docker Swarm
    log_info "Setting up Docker Swarm..."
    ansible-playbook ${ANSIBLE_ARGS} playbooks/setup-swarm.yml
    
    # Setup NGINX
    log_info "Setting up NGINX reverse proxy..."
    ansible-playbook ${ANSIBLE_ARGS} playbooks/setup-nginx.yml \
        -e "domain_name=${DOMAIN_NAME}" \
        -e "admin_email=${ADMIN_EMAIL}"
    
    # Deploy application
    log_info "Deploying TurboGate application..."
    ansible-playbook ${ANSIBLE_ARGS} playbooks/deploy-app.yml \
        -e "secret_key=${SECRET_KEY}" \
        -e "redis_password=${REDIS_PASSWORD}" \
        -e "image_tag=${IMAGE_TAG:-latest}" \
        -e "domain_name=${DOMAIN_NAME}"
    
    cd - > /dev/null
    
    log_success "Application deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check local health endpoint
    if curl -sf "http://${MANAGER_IP}/health" > /dev/null; then
        log_success "Health check passed (HTTP)"
    else
        log_warning "HTTP health check failed, SSL might not be ready yet"
    fi
    
    # Check service status
    log_info "Checking Docker services..."
    ssh "root@${MANAGER_IP}" "docker service ls"
    
    # Display access information
    echo
    log_success "Deployment completed successfully!"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  TurboGate is now deployed!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🌐 URL:        https://${DOMAIN_NAME}"
    echo "  🖥️  Server IP:  ${FLOATING_IP}"
    echo "  🔑 SSH:        ssh turbogate-manager"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "Useful commands:"
    echo "  - View logs:     ssh turbogate-manager 'docker service logs turbogate_turbogate'"
    echo "  - Service status: ssh turbogate-manager 'docker service ps turbogate_turbogate'"
    echo "  - Scale service: ssh turbogate-manager 'docker service scale turbogate_turbogate=3'"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    # Remove terraform plan file if it exists
    rm -f "${TERRAFORM_DIR}/tfplan"
}

# Main deployment flow
main() {
    log_info "Starting TurboGate deployment..."
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Load environment and check prerequisites
    load_environment
    check_prerequisites
    
    # Setup SSH
    setup_ssh_keys
    configure_ssh
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Update inventory and wait
    update_inventory
    wait_for_servers
    
    # Deploy application
    deploy_application
    
    # Verify deployment
    verify_deployment
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --destroy)
            log_warning "Destroying infrastructure..."
            cd "${TERRAFORM_DIR}"
            terraform destroy -auto-approve
            exit 0
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --destroy    Destroy all infrastructure"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            ;;
    esac
    shift
done

# Run main function
main "$@"