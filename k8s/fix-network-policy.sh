#!/bin/bash

# Fix Network Policy - Allow Traefik Access
# Run this on K3s machine with sudo

echo "=========================================="
echo "Fixing Network Policy for Traefik"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo:"
    echo "  sudo ./fix-network-policy.sh"
    exit 1
fi

APP_NAME="hello-world-python"
NAMESPACE="default"

echo "1️⃣  Current Network Policy..."
echo "-------------------------------------------"
kubectl get networkpolicy -n $NAMESPACE
echo ""

echo "2️⃣  Deleting restrictive network policy..."
echo "-------------------------------------------"
kubectl delete networkpolicy ${APP_NAME}-netpol -n $NAMESPACE 2>/dev/null || echo "No network policy to delete"
echo ""

echo "3️⃣  Creating permissive network policy..."
echo "-------------------------------------------"
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${APP_NAME}-netpol
  namespace: $NAMESPACE
spec:
  podSelector:
    matchLabels:
      app: $APP_NAME
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}  # Allow all ingress
  egress:
  - {}  # Allow all egress
EOF

echo "✅ Permissive network policy applied"
echo ""

echo "4️⃣  Waiting for changes to propagate..."
sleep 5
echo ""

echo "5️⃣  Testing service access..."
echo "-------------------------------------------"
CLUSTER_IP=$(kubectl get service $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
echo "Service IP: $CLUSTER_IP"
echo "Testing http://$CLUSTER_IP ..."

TEST_RESULT=$(kubectl run test-np --image=curlimages/curl --rm -i --restart=Never -- \
  curl -s -o /dev/null -w "%{http_code}" http://$CLUSTER_IP 2>/dev/null || echo "000")

if [ "$TEST_RESULT" = "200" ]; then
    echo "✅ Service accessible!"
else
    echo "❌ Service still not accessible (HTTP $TEST_RESULT)"
fi
echo ""

echo "6️⃣  Testing HTTPS access..."
echo "-------------------------------------------"
echo "Waiting 10 seconds for Traefik to update..."
sleep 10

HTTPS_RESULT=$(curl -k -s -o /dev/null -w "%{http_code}" https://hello-world-python.lab.allwaysbeginner.com 2>/dev/null || echo "000")

if [ "$HTTPS_RESULT" = "200" ]; then
    echo "✅ HTTPS access works!"
    echo ""
    curl -k -s https://hello-world-python.lab.allwaysbeginner.com | head -n 10
else
    echo "❌ HTTPS still returns: $HTTPS_RESULT"
    echo ""
    echo "Try restarting Traefik:"
    echo "  sudo kubectl rollout restart deployment traefik -n kube-system"
fi
echo ""

echo "=========================================="
echo "Fix Complete"
echo "=========================================="
echo ""
echo "Test from your MacBook:"
echo "  curl -k https://hello-world-python.lab.allwaysbeginner.com"
echo ""

# Made with Bob
