#!/bin/bash

# Test Service Directly - Bypass Ingress
# Run this on K3s machine (almak3s)

echo "=========================================="
echo "Direct Service Test"
echo "=========================================="
echo ""

APP_NAME="hello-world-python"
NAMESPACE="default"

echo "1️⃣  Testing Service via ClusterIP..."
echo "-------------------------------------------"
CLUSTER_IP=$(kubectl get service $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
echo "Service ClusterIP: $CLUSTER_IP"
echo ""

echo "Testing http://$CLUSTER_IP ..."
kubectl run test-curl --image=curlimages/curl --rm -i --restart=Never -- \
  curl -v http://$CLUSTER_IP 2>&1 | head -n 30

echo ""
echo "2️⃣  Testing Service via DNS..."
echo "-------------------------------------------"
echo "Testing http://$APP_NAME.$NAMESPACE.svc.cluster.local ..."
kubectl run test-curl-dns --image=curlimages/curl --rm -i --restart=Never -- \
  curl -v http://$APP_NAME.$NAMESPACE.svc.cluster.local 2>&1 | head -n 30

echo ""
echo "3️⃣  Testing Pod Directly..."
echo "-------------------------------------------"
POD_IP=$(kubectl get pod -l app=$APP_NAME -n $NAMESPACE -o jsonpath='{.items[0].status.podIP}')
echo "Pod IP: $POD_IP"
echo ""

echo "Testing http://$POD_IP:8080 ..."
kubectl run test-curl-pod --image=curlimages/curl --rm -i --restart=Never -- \
  curl -v http://$POD_IP:8080 2>&1 | head -n 30

echo ""
echo "4️⃣  Port Forward Test..."
echo "-------------------------------------------"
echo "Starting port-forward in background..."
kubectl port-forward service/$APP_NAME 8888:80 -n $NAMESPACE &
PF_PID=$!
sleep 3

echo "Testing http://localhost:8888 ..."
curl -v http://localhost:8888 2>&1 | head -n 20

kill $PF_PID 2>/dev/null
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "If any of the above tests work, the issue is with ingress configuration."
echo "If all tests fail, the issue is with the application or service."
echo ""

# Made with Bob
