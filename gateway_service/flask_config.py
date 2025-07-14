import os 
from typing import Optional, Dict
from dataclasses import dataclass


@dataclass
class ServiceConfig:
    """Configuration for a microservice."""
    url: str
    health_endpoint: str = "/health"
    timeout: int = 30
    enabled: bool = False
    
class Config:
    """Base configuration class."""
    
    # Flask settings
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
    DEBUG = os.environ.get('FLASK_ENV') == 'dev'
    TESTING = False
    
    # Redis settings
    REDIS_URL = os.environ.get('REDIS_URL', 'redis://localhost:6379/0')
    REDIS_ENABLED = os.environ.get('REDIS_ENABLED', 'true').lower() == 'true'
    
    # Gateway settings
    API_VERSION = 'v1'
    GATEWAY_NAME = 'TurboGate'
    RATE_LIMIT_PER_MINUTE = int(os.environ.get('RATE_LIMIT_PER_MINUTE', '100'))
    REQUEST_TIMEOUT = int(os.environ.get('REQUEST_TIMEOUT', '30'))
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
    
    # CORS settings
    CORS_ORIGINS = os.environ.get('CORS_ORIGINS', 'http://localhost:3000').split(',')
    
    
    # Microservices configuration
    SERVICES: Dict[str, ServiceConfig] = {
        'auth': ServiceConfig(
            url=os.environ.get('AUTH_SERVICE_URL', 'http://localhost:5001'),
            enabled=os.environ.get('AUTH_SERVICE_ENABLED', 'false').lower() == 'true'
        ),
        'jobs': ServiceConfig(
            url=os.environ.get('JOB_SERVICE_URL', 'http://localhost:5002'),
            enabled=os.environ.get('JOB_SERVICE_ENABLED', 'false').lower() == 'true'
        ),
        'partners': ServiceConfig(
            url=os.environ.get('PARTNER_SERVICE_URL', 'http://localhost:5003'),
            enabled=os.environ.get('PARTNER_SERVICE_ENABLED', 'false').lower() == 'true'
        ),
        'documents': ServiceConfig(
            url=os.environ.get('DOCUMENT_SERVICE_URL', 'http://localhost:5004'),
            timeout=60,  # Longer timeout for file operations
            enabled=os.environ.get('DOCUMENT_SERVICE_ENABLED', 'false').lower() == 'true'
        ),
        'payments': ServiceConfig(
            url=os.environ.get('PAYMENT_SERVICE_URL', 'http://localhost:5005'),
            enabled=os.environ.get('PAYMENT_SERVICE_ENABLED', 'false').lower() == 'true'
        ),
        'communication': ServiceConfig(
            url=os.environ.get('COMMUNICATION_SERVICE_URL', 'http://localhost:5006'),
            enabled=os.environ.get('COMMUNICATION_SERVICE_ENABLED', 'false').lower() == 'true'
        )
    }
    
    # Route mapping - maps URL prefixes to services
    ROUTE_MAPPINGS = {
        'auth': 'auth',
        'users': 'auth',
        'jobs': 'jobs',
        'assignments': 'jobs',
        'partners': 'partners',
        'onboarding': 'partners',
        'documents': 'documents',
        'uploads': 'documents',
        'payments': 'payments',
        'billing': 'payments',
        'escrow': 'payments',
        'messages': 'communication',
        'notifications': 'communication',
        'chat': 'communication'
    }
    
    # Public endpoints that don't require authentication
    PUBLIC_ENDPOINTS = [
        'auth/login',
        'auth/register',
        'auth/forgot_password',
        'auth/reset_password',
        'health',
        'metrics'
    ]
    
class DevelopmentConfig(Config):
    """Development configuration."""
    DEBUG = True
    LOG_LEVEL = 'DEBUG'
    
class ProductionConfig(Config):
    """Production configuration."""
    DEBUG = False
    TEST = False
    LOG_LEVEL = 'INFO'
    
class TestingConfig(Config):
    """Testing configuration."""
    DEBUG = True
    TEST = True
    REDIS_ENABLED = False
    LOG_LEVEL = 'DEBUG'
    
# Configuration mapping
config = {
    'dev': DevelopmentConfig,
    'test': TestingConfig,
    'prod': ProductionConfig,
    'default': DevelopmentConfig
}