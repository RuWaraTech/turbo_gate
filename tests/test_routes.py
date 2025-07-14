"""Test routes."""

import json

import pytest

from gateway_service import __version__


def test_gateway_health(client):
    """Test gateway health endpoint."""
    response = client.get("/gateway/health")
    assert response.status_code == 200

    data = json.loads(response.data)
    assert data["gateway"] == "TurboGate"
    assert data["status"] == "healthy"
    assert data["version"] == __version__


def test_services_health(client):
    """Test services health endpoint."""
    response = client.get("/gateway/health/services")
    assert response.status_code == 200

    data = json.loads(response.data)
    assert "services" in data
    assert "status" in data


def test_gateway_info(client):
    """Test gateway info endpoint."""
    response = client.get("/gateway/info")
    assert response.status_code == 200

    data = json.loads(response.data)
    assert data["name"] == "TurboGate"
    assert "enabled_services" in data
    assert "version" in data


def test_unknown_api_endpoint(client):
    """Test unknown API endpoint returns 404."""
    response = client.get("/api/v1/unknown-endpoint")
    assert response.status_code == 404

    data = json.loads(response.data)
    assert data["error"] == "Service not found"


def test_cors_headers(client):
    """Test CORS headers are present."""
    response = client.options("/api/v1/test")
    assert response.status_code == 200
    assert "Access-Control-Allow-Origin" in response.headers


def test_metrics_endpoint(client):
    """Test metrics endpoint."""
    response = client.get("/metrics")
    assert response.status_code == 200

    data = json.loads(response.data)
    assert "gateway" in data
    assert data["gateway"] == "TurboGate"
