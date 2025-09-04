import logging
import os
import sys
import time
import uuid
from functools import wraps
from typing import Optional

import redis
import structlog
from flask import current_app, g


def setup_logging() -> structlog.stdlib.BoundLogger:
    """Set up structured logging."""
    log_level = getattr(logging, current_app.config.get("LOG_LEVEL", "INFO"))

    logging.basicConfig(format="%(message)s", stream=sys.stdout, level=log_level)

    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer(),
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )

    return structlog.get_logger()


def get_redis_client() -> Optional[redis.Redis]:
    """Get Redis client instance."""
    if not current_app.config.get("REDIS_ENABLED", True):
        return None

    if not hasattr(g, "redis_client"):
        try:
            # Get Redis URL and password
            redis_url = current_app.config["REDIS_URL"]
            
            # Try to read Redis password from file if available
            redis_password = None
            redis_password_file = os.environ.get("REDIS_PASSWORD_FILE")
            if redis_password_file and os.path.exists(redis_password_file):
                try:
                    with open(redis_password_file, 'r') as f:
                        redis_password = f.read().strip()
                    # Update Redis URL with password
                    if redis_password and "redis://" in redis_url and "@" not in redis_url:
                        redis_url = redis_url.replace("redis://", f"redis://:{redis_password}@")
                except Exception as e:
                    current_app.logger.warning(f"Could not read Redis password from file: {e}")
            
            g.redis_client = redis.from_url(redis_url)
            # Test connection
            g.redis_client.ping()
        except Exception as e:
            current_app.logger.error(f"Redis connection failed: {e}")
            g.redis_client = None
    return g.redis_client


def generate_request_id() -> str:
    """Generate unique request ID."""
    return str(uuid.uuid4())


def timing_decorator(func):
    """Decorator to measure function execution time."""

    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        result = func(*args, **kwargs)
        duration = time.time() - start_time

        current_app.logger.debug(
            f"Function {func.__name__} executed", duration=f"{duration:.3f}s"
        )
        return result

    return wrapper
