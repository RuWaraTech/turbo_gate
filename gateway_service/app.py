import os
import time
from typing import Optional

import click
from flask import Flask, g
from flask_cors import CORS

from gateway_service import __version__
from gateway_service.flask_config import config
from gateway_service.routes import create_routes
from gateway_service.utils import setup_logging


def create_app(config_name: Optional[str] = None) -> Flask:
    """Flask application factory."""

    app = Flask(__name__)

    # Store app start time
    app.config["APP_START_TIME"] = time.time()

    # Load configuration
    if config_name is None:
        config_name = os.environ.get("FLASK_ENV", "dev")

    # Instantiate the config class (since we added __init__ methods)
    config_class = config.get(config_name, config["default"])
    app.config.from_object(config_class())

    # Initialize extensions
    CORS(app, origins=app.config.get("CORS_ORIGINS", ["*"]))

    # Set up logging
    with app.app_context():
        app.logger = setup_logging()

    # Store app start time in request context
    @app.before_request
    def before_request():
        g.app_start_time = app.config["APP_START_TIME"]

    # Register blueprints
    app.register_blueprint(create_routes())

    # Error handlers
    @app.errorhandler(404)
    def not_found(error):
        return {
            "error": "Not Found",
            "message": "Endpoint not found",
            "request_id": getattr(g, "request_id", "unknown"),
        }, 404

    @app.errorhandler(500)
    def internal_error(error):
        app.logger.error(f"Internal server error: {error}")
        return {
            "error": "Internal Server Error",
            "message": "An unexpected error occurred",
            "request_id": getattr(g, "request_id", "unknown"),
        }, 500

    @app.errorhandler(503)
    def service_unavailable(error):
        return {
            "error": "Service Unavailable",
            "message": "Service temporarily unavailable",
            "request_id": getattr(g, "request_id", "unknown"),
        }, 503

    app.logger.info(f"TurboGate v{__version__} started in {config_name} mode")

    return app


@click.group()
def cli():
    """TurboGate API Gateway CLI."""
    pass


@cli.command()
@click.option("--host", default="0.0.0.0", help="Host to bind to")
@click.option("--port", default=5000, help="Port to bind to")
@click.option("--debug", is_flag=True, help="Enable debug mode")
def run(host: str, port: int, debug: bool):
    """Run the development server."""
    app = create_app("dev" if debug else "prod")
    app.run(host=host, port=port, debug=debug)


@cli.command()
def health():
    """Check gateway health."""
    import requests

    try:
        response = requests.get("http://localhost:5000/gateway/health", timeout=5)
        if response.status_code == 200:
            click.echo("✅ Gateway is healthy")
            click.echo(f"Status: {response.json()}")
        else:
            click.echo(f"❌ Gateway unhealthy: {response.status_code}")
    except Exception as e:
        click.echo(f"❌ Gateway unreachable: {e}")


if __name__ == "__main__":
    cli()