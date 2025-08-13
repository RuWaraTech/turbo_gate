#!/bin/bash
set -e

# Color codes for better output readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
}

log_debug() {
    if [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
        echo -e "${BLUE}🔍 DEBUG:${NC} $1"
    fi
}

# Banner
echo -e "${BLUE}"
echo "=================================================="
echo "🚀 TurboGate Application Startup"
echo "=================================================="
echo -e "${NC}"

log_info "Starting TurboGate entrypoint script..."
log_info "Container started at: $(date)"
log_info "Process ID: $$"
log_info "User: $(whoami)"
log_info "Working directory: $(pwd)"

# Environment information
log_info "Environment: ${FLASK_ENV:-not-set}"
log_info "Log Level: ${LOG_LEVEL:-INFO}"
log_info "Domain: ${DOMAIN_NAME:-not-set}"
log_info "Version: ${VERSION:-unknown}"

# Debug: Show environment variables (excluding secrets)
log_debug "Environment variables (excluding secrets):"
if [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
    env | grep -E '^(FLASK|LOG|DOMAIN|VERSION|REDIS_URL)' | sort || log_debug "No relevant env vars found"
fi

# Check secrets directory
log_info "Checking Docker secrets availability..."
if [ -d "/run/secrets" ]; then
    log_success "Secrets directory exists: /run/secrets"
    log_debug "Secrets directory permissions: $(ls -ld /run/secrets)"
    
    log_info "Available secret files:"
    if ls -la /run/secrets/ 2>/dev/null; then
        SECRET_COUNT=$(ls -1 /run/secrets/ 2>/dev/null | wc -l)
        log_info "Found $SECRET_COUNT secret file(s)"
    else
        log_warning "Cannot list secrets directory contents"
    fi
else
    log_error "Secrets directory /run/secrets does not exist!"
    log_error "This might indicate a Docker secrets configuration issue"
fi

# Function to validate secret file
validate_secret_file() {
    local secret_path=$1
    local secret_name=$2
    local min_length=${3:-8}
    
    log_info "Validating secret: $secret_name"
    
    if [ ! -f "$secret_path" ]; then
        log_error "Secret file not found: $secret_path"
        return 1
    fi
    
    if [ ! -r "$secret_path" ]; then
        log_error "Secret file not readable: $secret_path"
        log_debug "File permissions: $(ls -l $secret_path)"
        return 1
    fi
    
    local secret_size=$(stat -c%s "$secret_path" 2>/dev/null || echo "0")
    if [ "$secret_size" -eq 0 ]; then
        log_error "Secret file is empty: $secret_path"
        return 1
    fi
    
    if [ "$secret_size" -lt "$min_length" ]; then
        log_error "Secret is too short: $secret_size bytes (minimum: $min_length bytes)"
        return 1
    fi
    
    log_success "$secret_name validated successfully (size: $secret_size bytes)"
    return 0
}

# Process SECRET_KEY
log_info "Processing SECRET_KEY..."
SECRET_KEY_PATH="/run/secrets/SECRET_KEY"
FALLBACK_SECRET_KEY_PATH="/run/secrets/turbogate_secret_key"

if validate_secret_file "$SECRET_KEY_PATH" "SECRET_KEY" 16; then
    export SECRET_KEY=$(cat "$SECRET_KEY_PATH")
    log_success "SECRET_KEY loaded from $SECRET_KEY_PATH"
elif validate_secret_file "$FALLBACK_SECRET_KEY_PATH" "SECRET_KEY (fallback)" 16; then
    export SECRET_KEY=$(cat "$FALLBACK_SECRET_KEY_PATH")
    log_success "SECRET_KEY loaded from fallback path: $FALLBACK_SECRET_KEY_PATH"
elif [ -n "${SECRET_KEY_FROM_ENV:-}" ]; then
    export SECRET_KEY="$SECRET_KEY_FROM_ENV"
    log_warning "SECRET_KEY loaded from environment variable (not recommended for production)"
else
    log_error "SECRET_KEY not found in any location:"
    log_error "  - Primary: $SECRET_KEY_PATH"
    log_error "  - Fallback: $FALLBACK_SECRET_KEY_PATH"
    log_error "  - Environment: SECRET_KEY_FROM_ENV"
    
    if [[ "${FLASK_ENV:-}" == "dev" || "${FLASK_ENV:-}" == "development" ]]; then
        log_warning "Development environment detected, using fallback SECRET_KEY"
        export SECRET_KEY="dev-secret-key-change-in-production-$(date +%s)"
    else
        log_error "Cannot proceed without SECRET_KEY in production environment"
        exit 1
    fi
fi

# Validate SECRET_KEY length
if [ ${#SECRET_KEY} -lt 16 ]; then
    log_error "SECRET_KEY is too short: ${#SECRET_KEY} characters (minimum: 16 characters)"
    exit 1
fi

log_success "SECRET_KEY configured (length: ${#SECRET_KEY} characters)"

# Process Redis Password
log_info "Processing Redis configuration..."
REDIS_PASSWORD_PATH="/run/secrets/redis_password"

if validate_secret_file "$REDIS_PASSWORD_PATH" "REDIS_PASSWORD" 8; then
    export REDIS_PASSWORD=$(cat "$REDIS_PASSWORD_PATH")
    export REDIS_URL="redis://:${REDIS_PASSWORD}@redis:6379/0"
    log_success "REDIS_PASSWORD loaded from $REDIS_PASSWORD_PATH"
    log_success "REDIS_URL configured with authentication"
elif [ -n "${REDIS_PASSWORD_FROM_ENV:-}" ]; then
    export REDIS_PASSWORD="$REDIS_PASSWORD_FROM_ENV"
    export REDIS_URL="redis://:${REDIS_PASSWORD}@redis:6379/0"
    log_warning "REDIS_PASSWORD loaded from environment variable"
    log_success "REDIS_URL configured with authentication"
else
    log_warning "Redis password not found, using fallback configuration"
    if [ -z "${REDIS_URL:-}" ]; then
        export REDIS_URL="redis://redis:6379/0"
        log_warning "Using fallback REDIS_URL without authentication: $REDIS_URL"
    else
        log_info "Using existing REDIS_URL: $REDIS_URL"
    fi
fi

# Additional environment validation
log_info "Performing additional environment validation..."

# Check for required Flask settings
if [ -z "${FLASK_ENV:-}" ]; then
    log_warning "FLASK_ENV not set, defaulting to 'production'"
    export FLASK_ENV="production"
fi

# Validate production environment
if [[ "${FLASK_ENV}" == "prod" || "${FLASK_ENV}" == "production" ]]; then
    log_info "Production environment detected, performing additional security checks..."
    
    if [[ "${SECRET_KEY}" == *"dev-secret-key"* ]]; then
        log_error "Development SECRET_KEY detected in production environment!"
        exit 1
    fi
    
    if [ -z "${REDIS_PASSWORD:-}" ]; then
        log_warning "Redis password not set in production environment"
    fi
    
    log_success "Production security checks passed"
fi

# Test Redis connectivity (if possible)
if command -v redis-cli >/dev/null 2>&1 && [ -n "${REDIS_PASSWORD:-}" ]; then
    log_info "Testing Redis connectivity..."
    if timeout 5 redis-cli -h redis -p 6379 -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
        log_success "Redis connectivity test passed"
    else
        log_warning "Redis connectivity test failed (Redis may not be ready yet)"
    fi
fi

# Set up additional Flask configuration
export PYTHONUNBUFFERED=1
export PYTHONDONTWRITEBYTECODE=1

# Display final configuration summary
log_info "Final configuration summary:"
echo "  📝 FLASK_ENV: ${FLASK_ENV}"
echo "  📝 LOG_LEVEL: ${LOG_LEVEL:-INFO}"
echo "  📝 DOMAIN_NAME: ${DOMAIN_NAME:-not-set}"
echo "  📝 VERSION: ${VERSION:-unknown}"
echo "  📝 SECRET_KEY: ✅ Configured (${#SECRET_KEY} chars)"
echo "  📝 REDIS_URL: ✅ Configured"
echo "  📝 REDIS_AUTH: $([ -n "${REDIS_PASSWORD:-}" ] && echo "✅ Enabled" || echo "❌ Disabled")"

# Health check function for development
if [[ "${FLASK_ENV}" == "dev" || "${LOG_LEVEL}" == "DEBUG" ]]; then
    log_debug "Development mode: Additional debugging enabled"
    
    # Create a simple health check endpoint test
    health_check() {
        log_debug "Internal health check will be available at startup"
    }
    health_check
fi

# Pre-execution checks
log_info "Performing pre-execution checks..."

# Check if the application code exists
if [ -f "gateway_service/app.py" ]; then
    log_success "Application code found"
elif [ -f "/gateway_app/gateway_service/app.py" ]; then
    log_success "Application code found in /gateway_app"
else
    log_error "Application code not found! Expected gateway_service/app.py"
    log_debug "Current directory contents:"
    ls -la . || log_debug "Cannot list current directory"
    exit 1
fi

# Check Python and dependencies
if command -v python >/dev/null 2>&1; then
    PYTHON_VERSION=$(python --version 2>&1)
    log_success "Python available: $PYTHON_VERSION"
else
    log_error "Python not found in PATH"
    exit 1
fi

if command -v poetry >/dev/null 2>&1; then
    POETRY_VERSION=$(poetry --version 2>&1)
    log_success "Poetry available: $POETRY_VERSION"
else
    log_error "Poetry not found in PATH"
    exit 1
fi

# Final startup message
echo -e "${GREEN}"
echo "=================================================="
echo "🎯 TurboGate Ready for Startup"
echo "=================================================="
echo -e "${NC}"

log_info "Executing command: $@"
log_info "Startup completed at: $(date)"

# Create a startup marker file
echo "$(date): TurboGate started successfully" > /tmp/turbogate_startup.log

# Execute the original command with proper signal handling
log_info "Handing over to application..."
exec "$@"