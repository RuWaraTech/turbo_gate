import time 
from typing import Optional
from flask import Blueprint, g, current_app, request, jsonify, Response, stream_with_context, g 
from flask_restx import Api, Resource, Namespace

import requests

from gateway_service.utils import setup_logging, get_redis_client
from gateway_service.middleware import request_middleware, rate_limit_middleware, cors_middleware
from gateway_service.service import ServiceClient, AuthService, HealthChecker
from gateway_service import __version__




def create_routes() -> Blueprint:
    """Create and configure routes blueprint."""
    
    # Create blueprint
    gateway_bp = Blueprint('gateway', __name__)
    
    # Setup Flask-RESTX
    api = Api(
        gateway_bp,
        title='TurboGate API Gateway',
        version=__version__,
        description='High-performance Flask API Gateway for Land Title Verification Platform',
        doc='/docs/',
        prefix='/gateway'
    )
    
    # Namespaces
    gateway_ns = api.namespace('', description='Gateway operations')
    
    @gateway_ns.route('/health')
    class GatewayHealth(Resource):
        """Gateway health endpoint."""
        
        def get(self):
            """Check gateway health."""
            redis_client = get_redis_client()
            redis_status = "connected" if redis_client else "disabled"
            
            return {
                'gateway': 'TurboGate',
                'status': 'healthy',
                'version': __version__,
                'redis': redis_status,
                'env' : current_app.config.get('FLASK_ENV'),
                'timestamp': time.time()
            }
    
    @gateway_ns.route('/health/services')
    class ServicesHealth(Resource):
        """All services health check."""
        
        def get(self):
            """Check health of all backend services."""
            health_status = HealthChecker.check_all_services()
            
            # Determine overall status
            enabled_services = {k: v for k, v in health_status.items() if v is not None}
            if not enabled_services:
                overall_status = 'no_services'
            else:
                overall_status = 'healthy' if all(enabled_services.values()) else 'degraded'
            
            return {
                'status': overall_status,
                'services': health_status,
                'enabled_count': len(enabled_services),
                'healthy_count': sum(1 for v in enabled_services.values() if v)
            }
    
    @gateway_ns.route('/info')
    class GatewayInfo(Resource):
        """Gateway information endpoint."""
        
        def get(self):
            """Get gateway information and configuration."""
            from flask import current_app
            
            services = current_app.config.get('SERVICES', {})
            enabled_services = [name for name, config in services.items() if config.enabled]
            
            return {
                'name': current_app.config.get('GATEWAY_NAME', 'TurboGate'),
                'version': __version__,
                'api_version': current_app.config.get('API_VERSION', 'v1'),
                'environment': 'development' if current_app.debug else 'production',
                'enabled_services': enabled_services,
                'rate_limit': current_app.config.get('RATE_LIMIT_PER_MINUTE', 100),
                'routes': list(current_app.config.get('ROUTE_MAPPINGS', {}).keys())
            }
    
    # Main proxy route for API requests
    @gateway_bp.route('/api/v1/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'])
    @cors_middleware()
    @request_middleware()
    @rate_limit_middleware()
    def proxy_to_service(path):
        """Proxy requests to appropriate microservices."""
        logger = setup_logging()
        
        # Handle preflight CORS requests
        if request.method == 'OPTIONS':
            return '', 200
        
        # Determine target service
        service_name = determine_target_service(path)
        if not service_name:
            logger.warning(f"No service found for path: {path}")
            return jsonify({
                'error': 'Service not found',
                'message': f'No service configured for endpoint: {path}',
                'request_id': getattr(g, 'request_id', 'unknown')
            }), 404
        
        # Check if service is enabled
        if not ServiceClient.is_service_enabled(service_name):
            logger.warning(f"Service {service_name} is not enabled")
            return jsonify({
                'error': 'Service not available',
                'message': f'The {service_name} service is currently not available',
                'request_id': getattr(g, 'request_id', 'unknown')
            }), 503
        
        # Check authentication if required
        if requires_authentication(path):
            auth_result = check_authentication()
            if auth_result:
                return auth_result  # Return error response
        
        # Check if service is healthy
        if not HealthChecker.check_service_health(service_name):
            logger.error(f"Service {service_name} is unhealthy")
            return jsonify({
                'error': 'Service unhealthy',
                'message': f'The {service_name} service is currently unavailable',
                'request_id': getattr(g, 'request_id', 'unknown')
            }), 503
        
        # Forward request to microservice
        try:
            return forward_request(service_name, path)
        except requests.exceptions.Timeout:
            logger.error(f"Service timeout: {service_name}")
            return jsonify({
                'error': 'Service timeout',
                'message': 'The request timed out',
                'request_id': getattr(g, 'request_id', 'unknown')
            }), 504
        except requests.exceptions.ConnectionError:
            logger.error(f"Service connection failed: {service_name}")
            return jsonify({
                'error': 'Service connection failed',
                'message': 'Unable to connect to service',
                'request_id': getattr(g, 'request_id', 'unknown')
            }), 503
        except Exception as e:
            logger.error(f"Request forwarding error: {e}", exc_info=True)
            return jsonify({
                'error': 'Internal server error',
                'message': 'An unexpected error occurred',
                'request_id': getattr(g, 'request_id', 'unknown')
            }), 500
    
    def determine_target_service(path: str) -> Optional[str]:
        """Determine which service should handle the request."""
        from flask import current_app
        
        route_mappings = current_app.config.get('ROUTE_MAPPINGS', {})
        
        # Find the service based on path prefix
        for prefix, service_name in route_mappings.items():
            if path.startswith(prefix):
                logger = setup_logging()
                logger.debug(f"Mapped path '{path}' to service '{service_name}'")
                return service_name
        
        return None
    
    def requires_authentication(path: str) -> bool:
        """Check if the endpoint requires authentication."""
        from flask import current_app
        
        public_endpoints = current_app.config.get('PUBLIC_ENDPOINTS', [])
        
        # Check if path matches any public endpoint
        for endpoint in public_endpoints:
            if path.startswith(endpoint):
                return False
        
        return True
    
    def check_authentication() -> Optional[tuple]:
        """Check request authentication."""
        logger = setup_logging()
        
        auth_header = request.headers.get('Authorization')
        
        if not auth_header or not auth_header.startswith('Bearer '):
            logger.warning("Missing or invalid authorization header")
            return jsonify({
                'error': 'Missing authorization',
                'message': 'Authorization header with Bearer token required',
                'request_id': getattr(g, 'request_id', 'unknown')
            }), 401
        
        token = auth_header.split(' ')[1]
        user_data = AuthService.validate_token(token)
        
        if not user_data:
            logger.warning("Invalid or expired token")
            return jsonify({
                'error': 'Invalid token',
                'message': 'Token is invalid or expired',
                'request_id': getattr(g, 'request_id', 'unknown')
            }), 401
        
        # Store user data in request context
        g.user = user_data
        logger.debug(f"Authenticated user: {user_data.get('user_id')}")
        return None
    
    def forward_request(service_name: str, path: str) -> Response:
        """Forward request to the target microservice."""
        logger = setup_logging()
        
        # Get service URL
        service_config = ServiceClient.get_service_config(service_name)
        service_url = service_config.url
        target_url = f"{service_url.rstrip('/')}/{path}"
        
        # Prepare headers (remove host header)
        headers = dict(request.headers)
        headers.pop('Host', None)
        
        # Add user context if authenticated
        if hasattr(g, 'user'):
            headers['X-User-ID'] = str(g.user.get('user_id', ''))
            headers['X-User-Role'] = g.user.get('role', '')
            headers['X-User-Email'] = g.user.get('email', '')
        
        # Add request context
        if hasattr(g, 'request_id'):
            headers['X-Request-ID'] = g.request_id
        
        # Make request to microservice
        try:
            response = requests.request(
                method=request.method,
                url=target_url,
                headers=headers,
                data=request.get_data(),
                params=request.args,
                timeout=service_config.timeout,
                stream=True
            )
            
            logger.info(
                "Request forwarded successfully",
                service=service_name,
                target_url=target_url,
                status_code=response.status_code
            )
            
            # Stream response back to client
            def generate():
                for chunk in response.iter_content(chunk_size=8192):
                    yield chunk
            
            # Create response with proper headers
            flask_response = Response(
                stream_with_context(generate()),
                status=response.status_code,
                content_type=response.headers.get('content-type')
            )
            
            # Copy relevant headers from microservice response
            headers_to_copy = [
                'Content-Type', 'Content-Length', 'Cache-Control', 
                'ETag', 'Last-Modified', 'X-Request-ID'
            ]
            
            for header in headers_to_copy:
                if header in response.headers:
                    flask_response.headers[header] = response.headers[header]
            
            return flask_response
            
        except Exception as e:
            logger.error(f"Error forwarding request to {service_name}: {e}")
            raise
    
    # Simple metrics endpoint
    @gateway_bp.route('/metrics')
    def metrics():
        """Basic metrics endpoint."""
        logger = setup_logging()
        
        try:
            redis_client = get_redis_client()
            
            # Basic stats
            stats = {
                'gateway': 'TurboGate',
                'version': __version__,
                'uptime': time.time() - getattr(g, 'app_start_time', time.time()),
                'redis_connected': redis_client is not None,
                'services_health': HealthChecker.check_all_services()
            }
            
            # Add Redis stats if available
            if redis_client:
                try:
                    info = redis_client.info()
                    stats['redis_info'] = {
                        'connected_clients': info.get('connected_clients', 0),
                        'used_memory_human': info.get('used_memory_human', '0B'),
                        'keyspace_hits': info.get('keyspace_hits', 0),
                        'keyspace_misses': info.get('keyspace_misses', 0)
                    }
                except Exception as e:
                    logger.error(f"Error getting Redis info: {e}")
            
            return jsonify(stats)
            
        except Exception as e:
            logger.error(f"Metrics error: {e}")
            return jsonify({
                'error': 'Metrics unavailable',
                'request_id': getattr(g, 'request_id', 'unknown')
            }), 503
    
    return gateway_bp