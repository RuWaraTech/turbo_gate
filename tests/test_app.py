"""test application factory."""

import pytest

from gateway_service import __version__
from gateway_service.app import create_app


def test_app_creation():
    """Test app creation."""
    app = create_app("test")
    assert app is not None
    assert app.config["TEST"] is True


def test_app_config():
    """Test app configuration."""
    app = create_app("test")
    assert "GATEWAY_NAME" in app.config
    assert app.config["GATEWAY_NAME"] == "TurboGate"
