"""Health check script."""

import json
import sys
from typing import Any, Dict

import requests


def check_gateway_health() -> Dict[str, Any]:
    """Check gateway health."""
    try:
        response = requests.get("http://localhost:5000/gateway/health", timeout=5)
        return {
            "status": "healthy" if response.status_code == 200 else "unhealthy",
            "status_code": response.status_code,
            "data": response.json() if response.status_code == 200 else None,
            "error": None,
        }
    except Exception as e:
        return {"status": "error", "status_code": None, "data": None, "error": str(e)}


def check_services_health() -> Dict[str, Any]:
    """Check all services health."""
    try:
        response = requests.get(
            "http://localhost:5000/gateway/health/services", timeout=10
        )
        return {
            "status": "healthy" if response.status_code == 200 else "unhealthy",
            "status_code": response.status_code,
            "data": response.json() if response.status_code == 200 else None,
            "error": None,
        }
    except Exception as e:
        return {"status": "error", "status_code": None, "data": None, "error": str(e)}


def main():
    """Main health check function."""
    print("🏎️ TurboGate Health Check")
    print("=" * 50)

    # Check gateway health
    gateway_health = check_gateway_health()
    print(f"Gateway Status: {gateway_health['status'].upper()}")

    if gateway_health["status"] == "healthy":
        print("✅ Gateway is running properly")
        if gateway_health["data"]:
            print(f"   Version: {gateway_health['data'].get('version', 'unknown')}")
            print(f"   Redis: {gateway_health['data'].get('redis', 'unknown')}")
    else:
        print("❌ Gateway is not healthy")
        if gateway_health["error"]:
            print(f"   Error: {gateway_health['error']}")
        sys.exit(1)

    # Check services health
    print("\nServices Health:")
    services_health = check_services_health()

    if services_health["status"] == "healthy" and services_health["data"]:
        services = services_health["data"].get("services", {})
        enabled_count = services_health["data"].get("enabled_count", 0)
        healthy_count = services_health["data"].get("healthy_count", 0)

        print(f"   Enabled: {enabled_count}, Healthy: {healthy_count}")

        for service_name, status in services.items():
            if status is None:
                print(f"   {service_name}: disabled")
            elif status:
                print(f"   {service_name}: ✅ healthy")
            else:
                print(f"   {service_name}: ❌ unhealthy")
    else:
        print("   ❌ Unable to check services health")
        if services_health["error"]:
            print(f"   Error: {services_health['error']}")

    print("\n🎯 Health check completed")


if __name__ == "__main__":
    main()
