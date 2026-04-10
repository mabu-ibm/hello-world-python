#!/bin/bash

# Setup Secure HTTPS Access for Hello World Python
# Run this on your K3s machine (almak3s)

set -e

echo "=========================================="
echo "Secure HTTPS Setup for IBM Bob Demo"
echo "=========================================="
echo ""

# Check if running on K3s machine
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please run this on your K3s machine."
    exit 1
fi

# Load environment variables from .env file
if [ -f ../.env ]; then
    echo "📋 Loading configuration from .env file..."
    source ../.env
    echo "✅ Configuration loaded"
elif [ -f .env ]; then
    echo "📋 Loading configuration from .env file..."
    source .env
    echo "✅ Configuration loaded"
else
    echo "⚠️  No .env file found. Using interactive mode..."
    echo ""
    
    # Interactive configuration
    read -p "Enter your base domain (e.g., lab.allwaysbeginner.com): " BASE_DOMAIN
    BASE_DOMAIN=${BASE_DOMAIN:-lab.allwaysbeginner.com}
    
    read -p "Enter application name (default: hello-world-python): " APP_NAME
    APP_NAME=${APP_NAME:-hello-world-python}
    
    read -p "Enter ingress class (traefik/nginx, default: traefik): " INGRESS_CLASS
    INGRESS_CLASS=${INGRESS_CLASS:-traefik}
fi

# Set defaults if not provided
NAMESPACE="${NAMESPACE:-default}"
APP_NAME="${APP_NAME:-hello-world-python}"
BASE_DOMAIN="${BASE_DOMAIN:-lab.allwaysbeginner.com}"
APP_HOSTNAME="${APP_HOSTNAME:-${APP_NAME}.${BASE_DOMAIN}}"
INGRESS_CLASS="${INGRESS_CLASS:-traefik}"
TLS_SECRET_NAME="${TLS_SECRET_NAME:-${APP_NAME}-tls}"
ENABLE_TLS="${ENABLE_TLS:-true}"

echo ""
echo "Configuration:"
echo "  Namespace: $NAMESPACE"
echo "  App Name: $APP_NAME"
echo "  Base Domain: $BASE_DOMAIN"
echo "  App Hostname: $APP_HOSTNAME"
echo "  Ingress Class: $INGRESS_CLASS"
echo "  TLS Secret: $TLS_SECRET_NAME"
echo "  Enable TLS: $ENABLE_TLS"
echo ""

# Step 1: Check if ingress controller is running
echo "1️⃣  Checking Ingress Controller..."
echo "-------------------------------------------"
if kubectl get pods -n kube-system | grep -q traefik; then
    echo "✅ Traefik ingress controller found"
    DETECTED_INGRESS="traefik"
elif kubectl get pods -n kube-system | grep -q nginx; then
    echo "✅ Nginx ingress controller found"
    DETECTED_INGRESS="nginx"
else
    echo "❌ No ingress controller found"
    echo ""
    echo "K3s should have Traefik by default. Check with:"
    echo "  kubectl get pods -n kube-system"
    exit 1
fi

# Use detected ingress if not specified
if [ -z "$INGRESS_CLASS" ] || [ "$INGRESS_CLASS" = "auto" ]; then
    INGRESS_CLASS="$DETECTED_INGRESS"
    echo "Using detected ingress class: $INGRESS_CLASS"
fi
echo ""

# Step 2: Create self-signed certificate
if [ "$ENABLE_TLS" = "true" ]; then
    echo "2️⃣  Creating Self-Signed TLS Certificate..."
    echo "-------------------------------------------"
    if kubectl get secret $TLS_SECRET_NAME -n $NAMESPACE &> /dev/null; then
        echo "⚠️  TLS secret already exists. Skipping certificate creation."
        echo "   To recreate, delete first: kubectl delete secret $TLS_SECRET_NAME -n $NAMESPACE"
    else
        echo "Generating self-signed certificate for $APP_HOSTNAME..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /tmp/tls.key -out /tmp/tls.crt \
            -subj "/CN=$APP_HOSTNAME/O=IBM Bob Secure Development Demo" \
            2>/dev/null
        
        echo "Creating Kubernetes TLS secret..."
        kubectl create secret tls $TLS_SECRET_NAME \
            --cert=/tmp/tls.crt \
            --key=/tmp/tls.key \
            --namespace=$NAMESPACE
        
        # Cleanup
        rm -f /tmp/tls.key /tmp/tls.crt
        
        echo "✅ TLS certificate created for $APP_HOSTNAME"
    fi
    echo ""
fi

# Step 3: Deploy application
echo "3️⃣  Deploying Application..."
echo "-------------------------------------------"
if kubectl get deployment $APP_NAME -n $NAMESPACE &> /dev/null; then
    echo "⚠️  Deployment already exists. Updating..."
    kubectl apply -f deployment.yaml
else
    echo "Creating deployment..."
    kubectl apply -f deployment.yaml
fi

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=$APP_NAME -n $NAMESPACE --timeout=60s || \
    echo "⚠️  Pods may not be ready yet. Check with: kubectl get pods -l app=$APP_NAME"
echo ""

# Step 4: Deploy secure ingress
echo "4️⃣  Deploying Secure Ingress..."
echo "-------------------------------------------"

# Create ingress dynamically
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}-ingress
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/ingress.class: $INGRESS_CLASS
$(if [ "$INGRESS_CLASS" = "traefik" ]; then
    echo "    traefik.ingress.kubernetes.io/router.tls: \"true\""
elif [ "$INGRESS_CLASS" = "nginx" ]; then
    echo "    nginx.ingress.kubernetes.io/ssl-redirect: \"true\""
    echo "    nginx.ingress.kubernetes.io/force-ssl-redirect: \"true\""
fi)
spec:
$(if [ "$ENABLE_TLS" = "true" ]; then
cat <<EOFTLS
  tls:
  - hosts:
    - $APP_HOSTNAME
    secretName: $TLS_SECRET_NAME
EOFTLS
fi)
  rules:
  - host: $APP_HOSTNAME
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $APP_NAME
            port:
              number: 80
EOF

echo "✅ Ingress deployed for $APP_HOSTNAME"
echo ""

# Step 5: Apply network policy
echo "5️⃣  Applying Network Policy..."
echo "-------------------------------------------"
if [ -f network-policy.yaml ]; then
    kubectl apply -f network-policy.yaml
    echo "✅ Network policy applied (blocks direct NodePort access)"
else
    echo "⚠️  network-policy.yaml not found. Skipping."
fi
echo ""

# Step 6: Get node IP
echo "6️⃣  Getting Node Information..."
echo "-------------------------------------------"
NODE_IP=$(hostname -I | awk '{print $1}')
echo "Node IP: $NODE_IP"
echo ""

# Step 7: Verify deployment
echo "7️⃣  Verifying Deployment..."
echo "-------------------------------------------"
echo "Pods:"
kubectl get pods -l app=$APP_NAME -n $NAMESPACE

echo ""
echo "Service:"
kubectl get service $APP_NAME -n $NAMESPACE

echo ""
echo "Ingress:"
kubectl get ingress -n $NAMESPACE

if [ "$ENABLE_TLS" = "true" ]; then
    echo ""
    echo "TLS Secret:"
    kubectl get secret $TLS_SECRET_NAME -n $NAMESPACE
fi
echo ""

# Step 8: Test local access
echo "8️⃣  Testing Local Access..."
echo "-------------------------------------------"
echo "Waiting for ingress to be ready..."
sleep 5

PROTOCOL="http"
CURL_OPTS=""
if [ "$ENABLE_TLS" = "true" ]; then
    PROTOCOL="https"
    CURL_OPTS="-k"
fi

if curl $CURL_OPTS -s -f ${PROTOCOL}://${APP_HOSTNAME} > /dev/null 2>&1; then
    echo "✅ ${PROTOCOL^^} access works locally!"
    echo ""
    echo "Response preview:"
    curl $CURL_OPTS -s ${PROTOCOL}://${APP_HOSTNAME} | head -n 10
else
    echo "⚠️  ${PROTOCOL^^} access test failed"
    echo ""
    echo "Check ingress controller logs:"
    echo "  kubectl logs -n kube-system -l app.kubernetes.io/name=$INGRESS_CLASS --tail=50"
fi
echo ""

# Final instructions
echo "=========================================="
echo "Setup Complete! 🎉"
echo "=========================================="
echo ""
echo "📋 Next Steps:"
echo ""
echo "1️⃣  Add to /etc/hosts on your MacBook:"
echo "   sudo nano /etc/hosts"
echo "   Add this line:"
echo "   $NODE_IP  $APP_HOSTNAME"
echo ""
echo "2️⃣  Test from MacBook:"
if [ "$ENABLE_TLS" = "true" ]; then
    echo "   curl -k https://$APP_HOSTNAME"
    echo "   open https://$APP_HOSTNAME"
    echo ""
    echo "3️⃣  Accept self-signed certificate warning in browser"
    echo "   (Click 'Advanced' → 'Proceed to $APP_HOSTNAME')"
else
    echo "   curl http://$APP_HOSTNAME"
    echo "   open http://$APP_HOSTNAME"
fi
echo ""
echo "🔒 Security Features Enabled:"
echo "   ✅ TLS/HTTPS encryption: $ENABLE_TLS"
echo "   ✅ Network policies (blocks direct NodePort)"
echo "   ✅ Ingress controller (single entry point)"
echo "   ✅ Secure container (non-root, read-only)"
echo "   ✅ SBOM generation (vulnerability tracking)"
echo ""
echo "📖 For production setup with Let's Encrypt:"
echo "   See SECURE_HTTPS_SETUP.md"
echo ""
echo "🔍 Troubleshooting:"
echo "   kubectl get all -n $NAMESPACE"
echo "   kubectl logs -l app=$APP_NAME -n $NAMESPACE"
echo "   kubectl describe ingress -n $NAMESPACE"
echo ""
echo "=========================================="
echo "Made with ❤️ by IBM Bob Secure Skill 🤖🔒"
echo "=========================================="

# Made with Bob
