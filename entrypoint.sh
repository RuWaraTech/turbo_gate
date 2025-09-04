#!/bin/bash
set -e

echo "🚀 Starting TurboGate..."
echo "Running as user: $(whoami) (UID: $(id -u), GID: $(id -g))"

# Debug: List /run/secrets directory
if [ -d "/run/secrets" ]; then
    echo "📁 Contents of /run/secrets:"
    ls -la /run/secrets/ 2>/dev/null || echo "Cannot list /run/secrets"
else
    echo "⚠️ /run/secrets directory does not exist"
fi

# Read secrets from files and export as environment variables
if [ -f "/run/secrets/SECRET_KEY" ]; then
    # Check if we can read the file
    if [ -r "/run/secrets/SECRET_KEY" ]; then
        export SECRET_KEY=$(cat /run/secrets/SECRET_KEY)
        SECRET_KEY_LENGTH=${#SECRET_KEY}
        echo "✅ SECRET_KEY loaded from secret file (length: $SECRET_KEY_LENGTH)"
    else
        echo "❌ SECRET_KEY file exists but is not readable by user $(whoami)"
        ls -la /run/secrets/SECRET_KEY
        exit 1
    fi
else
    echo "❌ SECRET_KEY secret file not found at /run/secrets/SECRET_KEY"
    exit 1
fi

if [ -f "/run/secrets/redis_password" ]; then
    if [ -r "/run/secrets/redis_password" ]; then
        export REDIS_PASSWORD=$(cat /run/secrets/redis_password)
        export REDIS_URL="redis://:${REDIS_PASSWORD}@redis-master:6379/0"
        echo "✅ REDIS_PASSWORD loaded and URL configured"
        # Don't print the actual password, just confirm it's set
        echo "   REDIS_URL format: redis://:****@redis-master:6379/0"
    else
        echo "❌ redis_password file exists but is not readable by user $(whoami)"
        ls -la /run/secrets/redis_password
        exit 1
    fi
else
    echo "⚠️  Redis password file not found at /run/secrets/redis_password"
    # Check if REDIS_URL is already set in environment
    if [ -z "$REDIS_URL" ]; then
        echo "⚠️  No REDIS_URL in environment either, using default"
        export REDIS_URL="redis://redis-master:6379/0"
    else
        echo "ℹ️  Using REDIS_URL from environment"
    fi
fi

# Basic validation
if [ ${#SECRET_KEY} -lt 16 ]; then
    echo "❌ SECRET_KEY too short (minimum 16 characters, got ${#SECRET_KEY})"
    exit 1
fi

# Test Redis connection if possible (optional)
if command -v python3 &> /dev/null; then
    echo "🔍 Testing Redis connection..."
    python3 -c "
import os
url = os.environ.get('REDIS_URL', '')
if url:
    print(f'   Redis URL configured: {url.replace(url.split('@')[0].split(\":\")[-1], \"****\") if \"@\" in url else url}')
else:
    print('   Warning: REDIS_URL not set')
" || true
fi

echo "✅ Environment configured successfully"
echo "🏃 Starting application with command: $@"

# Execute the original command
exec "$@"