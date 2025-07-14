"""dev server runner."""

import os
from gateway_service.app import create_app


def main():
    """Run development server."""
    os.environ.setdefault('FLASK_ENV', 'dev')
    
    app = create_app('dev')
    
    # Get port from environment
    port = int(os.environ.get('PORT', 5000))
    host = os.environ.get('HOST', '0.0.0.0')
    
    print(f"🏎️ Starting TurboGate on http://{host}:{port}")
    print("🔥 Development mode with hot reload enabled")
    
    app.run(
        host=host,
        port=port,
        debug=True,
        use_reloader=True
    )


if __name__ == '__main__':
    main()