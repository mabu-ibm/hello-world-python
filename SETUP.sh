#!/bin/bash

# Quick Setup Script for hello-world-python
# Run this on your K3s machine (almak3s)

set -e

echo "=========================================="
echo "Hello World Python - Quick Setup"
echo "=========================================="
echo ""

# Check if we're on K3s machine
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please run this on your K3s machine (almak3s)."
    echo ""
    echo "To run on K3s:"
    echo "  1. SSH to almak3s: ssh manfred@almak3s.lab.allwaysbeginner.com"
    echo "  2. Clone repo: git clone http://almabuild.lab.allwaysbeginner.com:3000/manfred/hello-world-python.git"
    echo "  3. cd hello-world-python"
    echo "  4. ./SETUP.sh"
    exit 1
fi

echo "✅ Running on K3s machine"
echo ""

# Load configuration from .env
if [ -f .env ]; then
    echo "📋 Loading configuration from .env..."
    source .env
    echo "✅ Configuration loaded"
    echo ""
    echo "Configuration:"
    echo "  App Name: $APP_NAME"
    echo "  Base Domain: $BASE_DOMAIN"
    echo "  App Hostname: $APP_HOSTNAME"
    echo "  K3s Hostname: $K3S_HOSTNAME"
    echo "  Enable TLS: $ENABLE_TLS"
    echo ""
else
    echo "❌ .env file not found!"
    echo ""
    echo "Please create .env file:"
    echo "  cp .env.template .env"
    echo "  nano .env"
    exit 1
fi

# Step 1: Deploy application
echo "1️⃣  Deploying Application..."
echo "-------------------------------------------"
kubectl apply -f k8s/deployment.yaml
echo "✅ Application deployed"
echo ""

# Step 2: Wait for pods
echo "2️⃣  Waiting for pods to be ready..."
echo "-------------------------------------------"
kubectl wait --for=condition=ready pod -l app=$APP_NAME -n default --timeout=60s || \
    echo "⚠️  Pods may not be ready yet"
echo ""

# Step 3: Setup secure HTTPS
echo "3️⃣  Setting up Secure HTTPS Access..."
echo "-------------------------------------------"
cd k8s
./setup-secure-https.sh
cd ..
echo ""

# Step 4: Get node IP
NODE_IP=$(hostname -I | awk '{print $1}')

# Final instructions
echo "=========================================="
echo "Setup Complete! 🎉"
echo "=========================================="
echo ""
echo "📋 Next Steps on Your MacBook:"
echo ""
echo "1️⃣  Add to /etc/hosts:"
echo "   sudo nano /etc/hosts"
echo "   Add this line:"
echo "   $NODE_IP  $APP_HOSTNAME"
echo ""
echo "2️⃣  Test access:"
echo "   curl -k https://$APP_HOSTNAME"
echo ""
echo "3️⃣  Open in browser:"
echo "   open https://$APP_HOSTNAME"
echo ""
echo "4️⃣  Accept self-signed certificate warning"
echo "   (Click 'Advanced' → 'Proceed to $APP_HOSTNAME')"
echo ""
echo "🔒 Security Features:"
echo "   ✅ TLS/HTTPS encryption"
echo "   ✅ Network policies"
echo "   ✅ Ingress controller"
echo "   ✅ SBOM generation"
echo "   ✅ Concert integration ready"
echo ""
echo "=========================================="
echo "Made with ❤️ by IBM Bob Secure Skill 🤖🔒"
echo "=========================================="

# Made with Bob
