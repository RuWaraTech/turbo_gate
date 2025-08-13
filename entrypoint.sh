#!/bin/bash
set -e

# Read secrets from files and export as environment variables
if [ -f "/run/secrets/SECRET_KEY" ]; then
    export SECRET_KEY=$(cat /run/secrets/SECRET_KEY)
    echo "✓ SECRET_KEY loaded from secret file"
fi

if [ -f "/run/secrets/redis_password" ]; then
    export REDIS_PASSWORD=$(cat /run/secrets/redis_password)
    # Update REDIS_URL with password
    export REDIS_URL="redis://:${REDIS_PASSWORD}@redis:6379/0"
    echo "✓ REDIS_PASSWORD loaded from secret file"
    echo "✓ REDIS_URL updated with authentication"
else
    # Fallback for development (no password)
    if [ -z "$REDIS_URL" ]; then
        export REDIS_URL="redis://redis:6379/0"
        echo "⚠ Using fallback REDIS_URL (no authentication)"
    fi
fi

# Execute the original command
exec "$@"