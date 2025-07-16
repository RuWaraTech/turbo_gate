from typing import Any, Dict, Optional

import jwt
import requests
from flask import current_app, g, request

from gateway_service.flask_config import ServiceConfig
from gateway_service.utils import setup_logging


class ServiceClient:
    """Base client for microservice communication."""

    @staticmethod
    def get_service_config(service_name: str) -> Optional[ServiceConfig]:
        """Get service configuration."""
        services = current_app.config.get("SERVICES", {})
        return services.get(service_name)

    @staticmethod
    def is_service_enabled(service_name: str) -> bool:
        """Check if service is enabled."""
        config = ServiceClient.get_service_config(service_name)
        return config and config.enabled

    @staticmethod
    def make_request(
        service_name: str,
        path: str,
        method: str = "GET",
        headers: Optional[Dict] = None,
        data: Any = None,
        params: Optional[Dict] = None,
    ) -> requests.Response:
        """Make HTTP request to a microservice."""

        service_config = ServiceClient.get_service_config(service_name)
        if not service_config:
            raise ValueError(f"Service {service_name} not configured")

        if not service_config.enabled:
            raise ValueError(f"Service {service_name} is not enabled")

        service_url = service_config.url
        url = f"{service_url.rstrip('/')}/{path.lstrip('/')}"

        # Prepare headers
        request_headers = headers or {}
        if "Content-Type" not in request_headers:
            request_headers["Content-Type"] = "application/json"

        # Add request ID for tracing
        if hasattr(g, "request_id"):
            request_headers["X-Request-ID"] = g.request_id

        # Get logger
        logger = setup_logging()

        try:
            response = requests.request(
                method=method,
                url=url,
                headers=request_headers,
                json=data if data else None,
                params=params,
                timeout=service_config.timeout,
            )

            logger.info(
                "Service request completed",
                service=service_name,
                method=method,
                url=url,
                status_code=response.status_code,
                duration=f"{response.elapsed.total_seconds():.3f}s",
            )

            return response

        except requests.exceptions.Timeout:
            logger.error(f"Service timeout: {service_name} {url}")
            raise
        except requests.exceptions.ConnectionError:
            logger.error(f"Service connection error: {service_name} {url}")
            raise
        except Exception as e:
            logger.error(f"Service request error: {service_name} {url} - {e}")
            raise


class AuthService:
    """Authentication service client."""

    @staticmethod
    def validate_token(token: str) -> Optional[Dict[str, Any]]:
        """Validate JWT token."""
        logger = setup_logging()

        try:
            # Try local validation first (faster)
            secret_key = current_app.config["SECRET_KEY"]
            payload = jwt.decode(token, secret_key, algorithms=["HS256"])

            logger.debug("Token validated locally", user_id=payload.get("user_id"))
            return payload

        except jwt.InvalidTokenError:
            # If local validation fails and auth service is enabled, try with service
            if ServiceClient.is_service_enabled("auth"):
                try:
                    response = ServiceClient.make_request(
                        service_name="auth",
                        path="validate-token",
                        method="POST",
                        data={"token": token},
                    )

                    if response.status_code == 200:
                        logger.debug("Token validated by auth service")
                        return response.json()
                    else:
                        logger.warning(
                            f"Auth service token validation failed: {response.status_code}"
                        )
                        return None

                except Exception as e:
                    logger.error(f"Auth service validation error: {e}")
                    return None
            else:
                logger.warning("Auth service not enabled, token validation failed")
                return None


class HealthChecker:
    """Health checking service."""

    @staticmethod
    def check_service_health(service_name: str) -> bool:
        """Check if a service is healthy."""
        logger = setup_logging()

        try:
            service_config = ServiceClient.get_service_config(service_name)

            if not service_config or not service_config.enabled:
                return False

            response = ServiceClient.make_request(
                service_name=service_name,
                path=service_config.health_endpoint,
                method="GET",
            )

            is_healthy = response.status_code == 200
            logger.debug(
                f"Health check for {service_name}: {'healthy' if is_healthy else 'unhealthy'}"
            )
            return is_healthy

        except Exception as e:
            logger.error(f"Health check failed for {service_name}: {e}")
            return False

    @staticmethod
    def check_all_services() -> Dict[str, Optional[bool]]:
        """Check health of all configured services."""
        services = current_app.config.get("SERVICES", {})
        health_status = {}

        for service_name, config in services.items():
            if config.enabled:
                health_status[service_name] = HealthChecker.check_service_health(
                    service_name
                )
            else:
                health_status[service_name] = None  # Service not enabled

        return health_status
