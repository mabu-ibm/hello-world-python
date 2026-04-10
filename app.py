#!/usr/bin/env python3
"""
Simple Flask Hello World Web Application
Demonstrates basic web app with health check endpoint
Built with IBM Bob Secure Skill
"""

from flask import Flask, jsonify, render_template_string
from datetime import datetime
import os

app = Flask(__name__)

# Configuration
VERSION = os.getenv('APP_VERSION', '1.0.0')
PORT = int(os.getenv('PORT', 8080))

# HTML Template with interactive button
HTML_TEMPLATE = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hello World - Python Flask</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
        }
        .container {
            background: white;
            border-radius: 10px;
            padding: 40px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        h1 {
            color: #667eea;
            margin-bottom: 10px;
        }
        .info {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .button-container {
            margin: 30px 0;
            text-align: center;
        }
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 15px 30px;
            font-size: 16px;
            border-radius: 5px;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        button:active {
            transform: translateY(0);
        }
        #result {
            margin-top: 20px;
            padding: 20px;
            background: #e8f5e9;
            border-left: 4px solid #4caf50;
            border-radius: 5px;
            display: none;
            animation: slideIn 0.3s ease-out;
        }
        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateY(-10px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        .badge {
            display: inline-block;
            padding: 5px 10px;
            background: #667eea;
            color: white;
            border-radius: 3px;
            font-size: 12px;
            margin-left: 10px;
        }
        .footer {
            margin-top: 30px;
            text-align: center;
            color: #666;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Hello World from Python Flask!</h1>
        <div class="info">
            <p><strong>Version:</strong> {{ version }} <span class="badge">SBOM Enabled</span></p>
            <p><strong>Status:</strong> Running</p>
            <p><strong>Timestamp:</strong> {{ timestamp }}</p>
        </div>
        
        <div class="button-container">
            <button onclick="showBuilder()">Built by:</button>
        </div>
        
        <div id="result">
            <h3>🤖 Built with IBM Bob Secure Skill</h3>
            <p>This application was automatically generated and deployed using:</p>
            <ul>
                <li>✅ Secure multi-stage Docker build</li>
                <li>✅ Automated SBOM generation</li>
                <li>✅ Kubernetes deployment with security policies</li>
                <li>✅ CI/CD pipeline with Gitea Actions</li>
                <li>✅ Optional IBM Concert integration</li>
            </ul>
        </div>
        
        <div class="footer">
            <p>Made with ❤️ by IBM Bob | <a href="/health">Health Check</a> | <a href="/api">API</a></p>
        </div>
    </div>
    
    <script>
        function showBuilder() {
            const result = document.getElementById('result');
            if (result.style.display === 'none' || result.style.display === '') {
                result.style.display = 'block';
            } else {
                result.style.display = 'none';
            }
        }
    </script>
</body>
</html>
'''

@app.route('/')
def hello():
    """Main hello world endpoint with interactive UI"""
    return render_template_string(
        HTML_TEMPLATE,
        version=VERSION,
        timestamp=datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    )

@app.route('/api')
def api():
    """JSON API endpoint"""
    return jsonify({
        'message': 'Hello World from Python Flask!',
        'version': VERSION,
        'timestamp': datetime.now().isoformat(),
        'status': 'running',
        'built_by': 'IBM Bob Secure Skill',
        'features': [
            'Secure multi-stage Docker build',
            'Automated SBOM generation',
            'Kubernetes deployment',
            'CI/CD pipeline',
            'Concert integration'
        ]
    })

@app.route('/health')
def health():
    """Health check endpoint for Kubernetes"""
    return jsonify({
        'status': 'healthy',
        'version': VERSION,
        'timestamp': datetime.now().isoformat()
    }), 200

@app.route('/ready')
def ready():
    """Readiness check endpoint for Kubernetes"""
    return jsonify({
        'status': 'ready',
        'version': VERSION
    }), 200

if __name__ == '__main__':
    print(f"Starting Hello World App v{VERSION} on port {PORT}")
    app.run(host='0.0.0.0', port=PORT, debug=False)

# Made with Bob
