import time
from functools import wraps

from flask import current_app, g, jsonify, request

from gateway_service.utils import generate_request_id, get_redis_client, setup_logging


def request_middleware():
    """Middleware to handle request lifecycle."""

    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # Setup request context
            g.request_id = generate_request_id()
            g.start_time = time.time()

            # Get logger
            logger = setup_logging()

            # Log request start
            logger.info(
                "Request started",
                request_id=g.request_id,
                method=request.method,
                path=request.path,
                remote_addr=request.remote_addr,
                user_agent=request.headers.get("User-Agent", "")[
                    :100
                ],  # Truncate long user agents
            )

            try:
                # Execute the request
                response = f(*args, **kwargs)
                status_code = getattr(response, "status_code", 200)

                # Log successful request
                duration = time.time() - g.start_time
                logger.info(
                    "Request completed",
                    request_id=g.request_id,
                    status_code=status_code,
                    duration=f"{duration:.3f}s",
                )

                return response

            except Exception as e:
                # Log error
                duration = time.time() - g.start_time
                logger.error(
                    "Request failed",
                    request_id=g.request_id,
                    error=str(e),
                    duration=f"{duration:.3f}s",
                    exc_info=True,
                )
                raise

        return decorated_function

    return decorator


def rate_limit_middleware():
    """Rate limiting middleware using Redis."""

    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # Skip rate limiting if Redis is disabled
            if not current_app.config.get("REDIS_ENABLED", True):
                return f(*args, **kwargs)

            try:
                redis_client = get_redis_client()

                if not redis_client:
                    # If Redis is unavailable, allow the request (fail open)
                    current_app.logger.warning(
                        "Redis unavailable, skipping rate limiting"
                    )
                    return f(*args, **kwargs)

                # Use IP address as rate limit key
                client_ip = request.environ.get(
                    "HTTP_X_FORWARDED_FOR", request.remote_addr
                )
                rate_limit_key = f"rate_limit:{client_ip}"

                # Check current request count
                current_requests = redis_client.get(rate_limit_key)
                limit = current_app.config["RATE_LIMIT_PER_MINUTE"]

                if current_requests is None:
                    # First request from this IP
                    redis_client.setex(rate_limit_key, 60, 1)
                elif int(current_requests) >= limit:
                    # Rate limit exceeded
                    current_app.logger.warning(
                        f"Rate limit exceeded for {client_ip}: {current_requests}/{limit}"
                    )
                    return (
                        jsonify(
                            {
                                "error": "Rate limit exceeded",
                                "message": f"Maximum {limit} requests per minute allowed",
                                "retry_after": 60,
                                "request_id": getattr(g, "request_id", "unknown"),
                            }
                        ),
                        429,
                    )
                else:
                    # Increment counter
                    redis_client.incr(rate_limit_key)

                return f(*args, **kwargs)

            except Exception as e:
                # If rate limiting fails, allow the request (fail open)
                current_app.logger.error(f"Rate limiting error: {e}")
                return f(*args, **kwargs)

        return decorated_function

    return decorator


def cors_middleware():
    """CORS middleware."""

    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # Handle preflight requests
            if request.method == "OPTIONS":
                response = jsonify({"status": "ok"})
            else:
                response = f(*args, **kwargs)

            # Add CORS headers
            if hasattr(response, "headers"):
                allowed_origins = current_app.config.get("CORS_ORIGINS", ["*"])
                origin = request.headers.get("Origin")

                if "*" in allowed_origins or origin in allowed_origins:
                    response.headers["Access-Control-Allow-Origin"] = origin or "*"

                response.headers[
                    "Access-Control-Allow-Methods"
                ] = "GET, POST, PUT, DELETE, OPTIONS, PATCH"
                response.headers[
                    "Access-Control-Allow-Headers"
                ] = "Content-Type, Authorization, X-Request-ID"
                response.headers["Access-Control-Expose-Headers"] = "X-Request-ID"
                response.headers["Access-Control-Max-Age"] = "3600"

            return response

        return decorated_function

    return decorator
