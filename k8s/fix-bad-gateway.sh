#!/bin/bash

# Fix Bad Gateway Issue
# Run this on K3s machine

echo "=========================================="
echo "Fixing Bad Gateway Issue"
echo "=========================================="
echo ""

APP_NAME="hello-world-python"
NAMESPACE="default"

echo "1️⃣  Checking Pod Status..."
echo "-------------------------------------------"
kubectl get pods -l app=$APP_NAME -n $NAMESPACE
echo ""

POD_STATUS=$(kubectl get pods -l app=$APP_NAME -n $NAMESPACE --no-headers 2>/dev/null | awk '{print $3}' | head -1)
echo "Pod Status: $POD_STATUS"

if [ "$POD_STATUS" != "Running" ]; then
    echo "❌ Pods are not running!"
    echo ""
    echo "Checking pod details..."
    kubectl describe pod -l app=$APP_NAME -n $NAMESPACE
    echo ""
    echo "Checking pod logs..."
    kubectl logs -l app=$APP_NAME -n $NAMESPACE --tail=50
    exit 1
fi

echo "✅ Pods are running"
echo ""

echo "2️⃣  Checking Service..."
echo "-------------------------------------------"
kubectl get service $APP_NAME -n $NAMESPACE
echo ""

echo "Service endpoints:"
kubectl get endpoints $APP_NAME -n $NAMESPACE
echo ""

ENDPOINTS=$(kubectl get endpoints $APP_NAME -n $NAMESPACE -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null)
if [ -z "$ENDPOINTS" ]; then
    echo "❌ No endpoints! Service can't reach pods."
    echo ""
    echo "Checking service selector..."
    kubectl get service $APP_NAME -n $NAMESPACE -o yaml | grep -A 3 "selector:"
    echo ""
    echo "Checking pod labels..."
    kubectl get pods -l app=$APP_NAME -n $NAMESPACE --show-labels
    echo ""
    echo "Issue: Service selector doesn't match pod labels!"
    exit 1
fi

echo "✅ Service has endpoints: $ENDPOINTS"
echo ""

echo "3️⃣  Testing Service Directly..."
echo "-------------------------------------------"
CLUSTER_IP=$(kubectl get service $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
echo "Service Cluster IP: $CLUSTER_IP"
echo "Testing http://$CLUSTER_IP ..."

TEST_RESULT=$(kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -s -o /dev/null -w "%{http_code}" http://$CLUSTER_IP 2>/dev/null || echo "000")

if [ "$TEST_RESULT" = "200" ]; then
    echo "✅ Service responds with 200 OK"
else
    echo "❌ Service returned: $TEST_RESULT"
    echo ""
    echo "Checking pod logs..."
    kubectl logs -l app=$APP_NAME -n $NAMESPACE --tail=20
    exit 1
fi
echo ""

echo "4️⃣  Checking Ingress Configuration..."
echo "-------------------------------------------"
kubectl get ingress -n $NAMESPACE
echo ""

echo "Ingress backend service:"
kubectl get ingress -n $NAMESPACE -o yaml | grep -A 5 "backend:"
echo ""

echo "5️⃣  Restarting Traefik..."
echo "-------------------------------------------"
echo "Restarting Traefik to pick up changes..."
kubectl rollout restart deployment traefik -n kube-system
kubectl rollout status deployment traefik -n kube-system --timeout=60s
echo "✅ Traefik restarted"
echo ""

echo "6️⃣  Waiting for changes to propagate..."
echo "-------------------------------------------"
echo "Waiting 10 seconds..."
sleep 10
echo ""

echo "7️⃣  Testing HTTPS Access..."
echo "-------------------------------------------"
echo "Testing https://hello-world-python.lab.allwaysbeginner.com ..."
HTTPS_RESULT=$(curl -k -s -o /dev/null -w "%{http_code}" https://hello-world-python.lab.allwaysbeginner.com 2>/dev/null || echo "000")

if [ "$HTTPS_RESULT" = "200" ]; then
    echo "✅ HTTPS access works!"
    echo ""
    curl -k -s https://hello-world-python.lab.allwaysbeginner.com | head -n 10
else
    echo "❌ HTTPS returned: $HTTPS_RESULT"
    echo ""
    echo "Checking Traefik logs..."
    kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=30
fi
echo ""

echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="
echo ""
echo "Summary:"
echo "  Pods: $POD_STATUS"
echo "  Service Endpoints: $ENDPOINTS"
echo "  Service Test: $TEST_RESULT"
echo "  HTTPS Test: $HTTPS_RESULT"
echo ""

if [ "$HTTPS_RESULT" = "200" ]; then
    echo "✅ Everything is working!"
    echo ""
    echo "Access at: https://hello-world-python.lab.allwaysbeginner.com"
else
    echo "⚠️  Still having issues. Check:"
    echo "  1. kubectl logs -l app=$APP_NAME -n $NAMESPACE"
    echo "  2. kubectl logs -n kube-system -l app.kubernetes.io/name=traefik"
    echo "  3. kubectl describe ingress -n $NAMESPACE"
fi
echo ""

# Made with Bob
