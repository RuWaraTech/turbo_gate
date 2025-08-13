#!/bin/bash
set -e

echo "🚀 Starting TurboGate..."

# Read secrets from files and export as environment variables
if [ -f "/run/secrets/SECRET_KEY" ]; then
    export SECRET_KEY=$(cat /run/secrets/SECRET_KEY)
    echo "✅ SECRET_KEY loaded from secret file"
else
    echo "❌ SECRET_KEY secret file not found"
    exit 1
fi

if [ -f "/run/secrets/redis_password" ]; then
    export REDIS_PASSWORD=$(cat /run/secrets/redis_password)
    export REDIS_URL="redis://:${REDIS_PASSWORD}@redis:6379/0"
    echo "✅ REDIS_PASSWORD loaded and URL configured"
else
    echo "⚠️  Redis password not found, using fallback"
    export REDIS_URL="${REDIS_URL:-redis://redis:6379/0}"
fi

# Basic validation
if [ ${#SECRET_KEY} -lt 16 ]; then
    echo "❌ SECRET_KEY too short (minimum 16 characters)"
    exit 1
fi

echo "✅ Environment configured successfully"
echo "🏃 Starting application..."

# Execute the original command
exec "$@"