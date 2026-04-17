#!/bin/bash
# Comprehensive Bad Gateway Diagnostic Script
# Run this on the almak3s machine to diagnose ingress issues

set -e

echo "=========================================="
echo "Bad Gateway Diagnostic Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

echo "1. Checking Pod Status..."
echo "-------------------------------------------"
kubectl get pods -n default -l app=hello-world-python -o wide
echo ""

echo "2. Checking Service Configuration..."
echo "-------------------------------------------"
kubectl get svc hello-world-python -n default -o yaml | grep -A 10 "spec:"
echo ""

echo "3. Checking Service Endpoints..."
echo "-------------------------------------------"
kubectl get endpoints hello-world-python -n default
echo ""

echo "4. Testing Pod Health Directly (from within pod)..."
echo "-------------------------------------------"
POD_NAME=$(kubectl get pods -n default -l app=hello-world-python -o jsonpath='{.items[0].metadata.name}')
echo "Testing pod: $POD_NAME"
kubectl exec -n default $POD_NAME -- curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:8080/health || echo "Failed to connect to pod"
echo ""

echo "5. Testing Service from within cluster..."
echo "-------------------------------------------"
kubectl run test-curl --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://hello-world-python.default.svc.cluster.local/health || echo "Failed to connect to service"
echo ""

echo "6. Checking Ingress Configuration..."
echo "-------------------------------------------"
kubectl describe ingress hello-world-python -n default
echo ""

echo "7. Checking Traefik Logs (last 20 lines)..."
echo "-------------------------------------------"
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=20 | grep -i "hello-world" || echo "No relevant Traefik logs found"
echo ""

echo "8. Testing Direct Pod Access (ClusterIP)..."
echo "-------------------------------------------"
POD_IP=$(kubectl get pod $POD_NAME -n default -o jsonpath='{.status.podIP}')
echo "Pod IP: $POD_IP"
kubectl run test-curl-pod --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://$POD_IP:8080/health || echo "Failed to connect to pod IP"
echo ""

echo "9. Checking for Network Policies..."
echo "-------------------------------------------"
kubectl get networkpolicies -n default
echo ""

echo "10. Checking Traefik IngressRoute (if exists)..."
echo "-------------------------------------------"
kubectl get ingressroute -n default 2>/dev/null || echo "No IngressRoutes found"
echo ""

echo "11. Testing NodePort Access..."
echo "-------------------------------------------"
NODE_PORT=$(kubectl get svc hello-world-python -n default -o jsonpath='{.spec.ports[0].nodePort}')
echo "NodePort: $NODE_PORT"
echo "Testing: curl -s -o /dev/null -w 'HTTP Status: %{http_code}\n' http://localhost:$NODE_PORT/health"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:$NODE_PORT/health || echo "Failed to connect via NodePort"
echo ""

echo "12. Checking Ingress Host Resolution..."
echo "-------------------------------------------"
INGRESS_HOST=$(kubectl get ingress hello-world-python -n default -o jsonpath='{.spec.rules[0].host}')
echo "Ingress Host: $INGRESS_HOST"
if [ ! -z "$INGRESS_HOST" ]; then
    echo "Testing: curl -s -o /dev/null -w 'HTTP Status: %{http_code}\n' -H 'Host: $INGRESS_HOST' http://192.168.8.31/health"
    curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" -H "Host: $INGRESS_HOST" http://192.168.8.31/health || echo "Failed to connect via ingress"
else
    echo "No host specified in ingress"
fi
echo ""

echo "13. Checking Pod Logs for Errors..."
echo "-------------------------------------------"
kubectl logs $POD_NAME -n default --tail=30
echo ""

echo "=========================================="
echo "Diagnostic Summary"
echo "=========================================="
echo ""
echo "Common Bad Gateway Causes:"
echo "1. Service selector mismatch with pod labels"
echo "2. Wrong service port or targetPort"
echo "3. Pod not ready (failing health checks)"
echo "4. Network policy blocking traffic"
echo "5. Traefik misconfiguration"
echo "6. Missing or incorrect ingress annotations"
echo ""
echo "Next Steps:"
echo "- Review the output above for any errors"
echo "- Check if pods are in 'Running' state and 'Ready'"
echo "- Verify service endpoints are populated"
echo "- Test NodePort access (should work if pods are healthy)"
echo "- Check Traefik logs for routing errors"
echo ""

# Made with Bob
