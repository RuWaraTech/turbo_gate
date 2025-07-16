"""test configuration."""

import pytest

from gateway_service.app import create_app


@pytest.fixture
def app():
    """create test app."""
    app = create_app("test")
    app.config["TEST"] = True
    app.config["REDIS_ENABLED"] = False  # Disable Redis for tests
    return app


@pytest.fixture
def client(app):
    """Create test client."""
    return app.test_client()


@pytest.fixture
def runner(app):
    """Create test CLI runner."""
    return app.test_cli_runner()
