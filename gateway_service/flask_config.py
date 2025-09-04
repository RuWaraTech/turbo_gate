import os
from dataclasses import dataclass
from typing import Dict


@dataclass
class ServiceConfig:
    """Configuration for a microservice."""

    url: str
    health_endpoint: str = "/health"
    timeout: int = 30
    enabled: bool = False


class Config:
    """Base configuration class."""

    def __init__(self):
        """Initialize configuration with validation."""
        # Validate SECRET_KEY - try file first, then environment variable
        secret_key = None
        secret_key_file = os.environ.get("SECRET_KEY_FILE")
        if secret_key_file and os.path.exists(secret_key_file):
            try:
                with open(secret_key_file, 'r') as f:
                    secret_key = f.read().strip()
            except Exception as e:
                raise ValueError(f"Could not read SECRET_KEY from file {secret_key_file}: {e}")
        else:
            secret_key = os.environ.get("SECRET_KEY")
        
        if not secret_key:
            raise ValueError("No SECRET_KEY set for Flask application. Did you follow the setup instructions?")
        if len(secret_key) < 16:
            raise ValueError("SECRET_KEY must be at least 16 characters long for security")
        self.SECRET_KEY = secret_key

    # Flask settings
    DEBUG = os.environ.get("FLASK_ENV") == "dev"
    TEST = False

    # Redis settings
    REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
    REDIS_ENABLED = os.environ.get("REDIS_ENABLED", "true").lower() == "true"

    # Gateway settings
    API_VERSION = "v1"
    GATEWAY_NAME = "TurboGate"
    RATE_LIMIT_PER_MINUTE = int(os.environ.get("RATE_LIMIT_PER_MINUTE", "100"))
    REQUEST_TIMEOUT = int(os.environ.get("REQUEST_TIMEOUT", "30"))
    LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")

    # CORS settings
    CORS_ORIGINS = os.environ.get("CORS_ORIGINS", "http://localhost:3000").split(",")

    # Microservices configuration
    SERVICES: Dict[str, ServiceConfig] = {
        "auth": ServiceConfig(
            url=os.environ.get("AUTH_SERVICE_URL", "http://localhost:5001"),
            enabled=os.environ.get("AUTH_SERVICE_ENABLED", "false").lower() == "true",
        ),
        "jobs": ServiceConfig(
            url=os.environ.get("JOB_SERVICE_URL", "http://localhost:5002"),
            enabled=os.environ.get("JOB_SERVICE_ENABLED", "false").lower() == "true",
        ),
        "partners": ServiceConfig(
            url=os.environ.get("PARTNER_SERVICE_URL", "http://localhost:5003"),
            enabled=os.environ.get("PARTNER_SERVICE_ENABLED", "false").lower()
            == "true",
        ),
        "documents": ServiceConfig(
            url=os.environ.get("DOCUMENT_SERVICE_URL", "http://localhost:5004"),
            timeout=60,  # Longer timeout for file operations
            enabled=os.environ.get("DOCUMENT_SERVICE_ENABLED", "false").lower()
            == "true",
        ),
        "payments": ServiceConfig(
            url=os.environ.get("PAYMENT_SERVICE_URL", "http://localhost:5005"),
            enabled=os.environ.get("PAYMENT_SERVICE_ENABLED", "false").lower()
            == "true",
        ),
        "communication": ServiceConfig(
            url=os.environ.get("COMMUNICATION_SERVICE_URL", "http://localhost:5006"),
            enabled=os.environ.get("COMMUNICATION_SERVICE_ENABLED", "false").lower()
            == "true",
        ),
    }

    # Route mapping - maps URL prefixes to services
    ROUTE_MAPPINGS = {
        "auth": "auth",
        "users": "auth",
        "jobs": "jobs",
        "assignments": "jobs",
        "partners": "partners",
        "onboarding": "partners",
        "documents": "documents",
        "uploads": "documents",
        "payments": "payments",
        "billing": "payments",
        "escrow": "payments",
        "messages": "communication",
        "notifications": "communication",
        "chat": "communication",
    }

    # Public endpoints that don't require authentication
    PUBLIC_ENDPOINTS = [
        "auth/login",
        "auth/register",
        "auth/forgot_password",
        "auth/reset_password",
        "health",
        "metrics",
    ]


class DevelopmentConfig(Config):
    """Development configuration."""

    def __init__(self):
        """Initialize development configuration."""
        # Allow fallback SECRET_KEY for development only
        secret_key = os.environ.get("SECRET_KEY", "dev-secret-key-change-in-production")
        if len(secret_key) < 16:
            raise ValueError("SECRET_KEY must be at least 16 characters long for security")
        self.SECRET_KEY = secret_key
    ENVIRONMENT = "dev"
    DEBUG = True
    LOG_LEVEL = "DEBUG"


class ProductionConfig(Config):
    """Production configuration."""

    def __init__(self):
        """Initialize production configuration with strict validation."""
        super().__init__()
        # Additional production-specific validation
        if self.SECRET_KEY == "dev-secret-key-change-in-production":
            raise ValueError("Default SECRET_KEY cannot be used in production")
    ENVIRONMENT = "prod"
    DEBUG = False
    TEST = False
    LOG_LEVEL = "INFO"


class TestingConfig(Config):
    """Testing configuration."""

    def __init__(self):
        """Initialize testing configuration."""
        # Use a test-specific SECRET_KEY
        secret_key = os.environ.get("SECRET_KEY", "test-secret-key-for-testing-only")
        if len(secret_key) < 16:
            raise ValueError("SECRET_KEY must be at least 16 characters long for security")
        self.SECRET_KEY = secret_key
    ENVIRONMENT = "test"
    DEBUG = True
    TEST = True
    REDIS_ENABLED = False
    LOG_LEVEL = "DEBUG"


# Configuration mapping
config = {
    "dev": DevelopmentConfig,
    "test": TestingConfig,
    "prod": ProductionConfig,
    "default": DevelopmentConfig,
}