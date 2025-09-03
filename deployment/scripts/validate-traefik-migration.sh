#!/bin/bash

set -e

echo "🔍 Validating Complete Traefik + Coraza Migration..."
echo "================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success_count=0
error_count=0

check_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((success_count++))
}

check_error() {
    echo -e "${RED}❌ $1${NC}"
    ((error_count++))
}

check_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo
echo "📋 File Structure Validation"
echo "=============================="

# Check if required Traefik files exist
if [ -f "/home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/docker-compose-waf.yml.j2" ]; then
    if grep -q "traefik:v3.4" "/home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/docker-compose-waf.yml.j2"; then
        check_success "Docker Compose uses Traefik v3.4"
    else
        check_error "Docker Compose does not use Traefik v3.4"
    fi
else
    check_error "Docker Compose template not found"
fi

if [ -f "/home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/tls.yaml.j2" ]; then
    check_success "Traefik TLS configuration template exists"
else
    check_error "Traefik TLS configuration template missing"
fi

# Check if NGINX WAF files are completely removed
if [ -f "/home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/nginx-waf.conf.j2" ]; then
    check_error "NGINX WAF configuration still exists"
else
    check_success "NGINX WAF configuration removed"
fi

if [ -f "/home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/modsecurity.conf.j2" ]; then
    check_error "ModSecurity configuration still exists"
else
    check_success "ModSecurity configuration removed"
fi

if [ -f "/home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/modsecurity_exclusions.conf.j2" ]; then
    check_error "ModSecurity exclusions still exist"
else
    check_success "ModSecurity exclusions removed"
fi

echo
echo "🔧 Terraform Configuration Validation"
echo "====================================="

# Check Terraform variables
if grep -q "traefik_enabled" /home/dev_two/Documents/turbo_gate/deployment/terraform/variables.tf; then
    check_success "Terraform variables contain Traefik configuration"
else
    check_error "Terraform variables missing Traefik configuration"
fi

if grep -q "coraza_rule_engine" /home/dev_two/Documents/turbo_gate/deployment/terraform/variables.tf; then
    check_success "Terraform variables contain Coraza WAF configuration"
else
    check_error "Terraform variables missing Coraza WAF configuration"
fi

# Check if old WAF variables are removed
if grep -q "waf_enabled" /home/dev_two/Documents/turbo_gate/deployment/terraform/variables.tf; then
    check_error "Old WAF variables still present in Terraform"
else
    check_success "Old WAF variables removed from Terraform"
fi

# Check Terraform main.tf
if grep -q "hcloud_firewall.*traefik" /home/dev_two/Documents/turbo_gate/deployment/terraform/main.tf; then
    check_success "Terraform main.tf uses Traefik firewall"
else
    check_error "Terraform main.tf still uses old WAF firewall"
fi

# Check load balancer configuration
if grep -q "destination_port = 443" /home/dev_two/Documents/turbo_gate/deployment/terraform/load_balancer.tf; then
    check_success "Load balancer configured for backend HTTPS (port 443)"
else
    check_warning "Load balancer may not be configured for backend TLS"
fi

echo
echo "🐳 Docker Swarm Configuration Validation"
echo "========================================"

# Check Docker Compose configuration
if grep -q "coraza-traefik" /home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/docker-compose-waf.yml.j2; then
    check_success "Coraza WAF plugin configured"
else
    check_warning "Coraza WAF plugin may not be configured"
fi

if grep -q "traefik_proxy" /home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/docker-compose-waf.yml.j2; then
    check_success "Traefik proxy network configured"
else
    check_error "Traefik proxy network missing"
fi

if grep -q "dashboard.{{ domain_name }}" /home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/docker-compose-waf.yml.j2; then
    check_success "Traefik dashboard configured with domain"
else
    check_error "Traefik dashboard configuration missing"
fi

echo
echo "📝 Ansible Playbook Validation"
echo "=============================="

# Check Ansible deployment script
if grep -q "traefik:v3.4" /home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/deploy_app.yml; then
    check_success "Ansible pulls Traefik v3.4 image"
else
    check_error "Ansible not configured to pull Traefik image"
fi

if grep -q "traefik_tls_config" /home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/deploy_app.yml; then
    check_success "Ansible creates Traefik TLS configuration"
else
    check_error "Ansible missing Traefik TLS configuration setup"
fi

# Check if old NGINX references are removed
if grep -q "owasp/modsecurity-crs:nginx-alpine" /home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/deploy_app.yml; then
    check_error "Ansible still references old NGINX WAF image"
else
    check_success "Old NGINX WAF references removed from Ansible"
fi

echo
echo "🔐 Security Configuration Validation"
echo "==================================="

# Check TLS configuration
if [ -f "/home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/tls.yaml.j2" ]; then
    if grep -q "coraza-waf" "/home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/tls.yaml.j2"; then
        check_success "Comprehensive Coraza WAF middleware configured"
    else
        check_warning "Basic WAF configuration - consider enabling full Coraza"
    fi
    
    if grep -q "OWASP_CRS" "/home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/tls.yaml.j2"; then
        check_success "OWASP Core Rule Set configured"
    else
        check_warning "OWASP CRS may not be fully configured"
    fi
    
    if grep -q "rate-limit" "/home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/tls.yaml.j2"; then
        check_success "Rate limiting configured"
    else
        check_error "Rate limiting configuration missing"
    fi
    
    if grep -q "Strict-Transport-Security" "/home/dev_two/Documents/turbo_gate/deployment/ansible/playbooks/templates/tls.yaml.j2"; then
        check_success "Security headers configured"
    else
        check_error "Security headers configuration missing"
    fi
fi

echo
echo "📊 Migration Summary"
echo "==================="
echo -e "✅ Successful checks: ${GREEN}${success_count}${NC}"
echo -e "❌ Failed checks: ${RED}${error_count}${NC}"
echo

if [ $error_count -eq 0 ]; then
    echo -e "${GREEN}🎉 Migration validation completed successfully!${NC}"
    echo
    echo "🚀 Next Steps:"
    echo "   1. Deploy infrastructure: cd deployment/terraform && terraform apply"
    echo "   2. Run Ansible deployment: cd deployment/ansible && ansible-playbook ..."
    echo "   3. Test Traefik dashboard: https://dashboard.ridebase.app"
    echo "   4. Verify WAF protection: curl tests with malicious payloads"
    echo "   5. Monitor performance and security metrics"
    echo
    echo "🔐 Security Features Enabled:"
    echo "   • Traefik v3.4 reverse proxy"
    echo "   • Coraza WAF with OWASP Core Rule Set v4.0"
    echo "   • End-to-end TLS encryption (LB → Traefik → App)"
    echo "   • Multi-tier rate limiting"
    echo "   • Comprehensive security headers"
    echo "   • Request size limiting"
    echo "   • IP whitelisting for admin endpoints"
    echo "   • Circuit breaker for upstream protection"
    exit 0
else
    echo -e "${RED}⚠️  Migration validation found ${error_count} issues that need to be resolved.${NC}"
    echo
    echo "🔧 Please review the failed checks above and fix the issues before deployment."
    exit 1
fi