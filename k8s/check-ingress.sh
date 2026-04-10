#!/bin/bash

# Check Ingress Configuration
# Run this on K3s machine to diagnose ingress issues

echo "=========================================="
echo "Ingress Configuration Check"
echo "=========================================="
echo ""

# Load .env if available
if [ -f ../.env ]; then
    source ../.env
elif [ -f .env ]; then
    source .env
fi

APP_NAME="${APP_NAME:-hello-world-python}"
NAMESPACE="${NAMESPACE:-default}"

echo "1️⃣  Checking Pods..."
echo "-------------------------------------------"
kubectl get pods -l app=$APP_NAME -n $NAMESPACE
echo ""

echo "2️⃣  Checking Service..."
echo "-------------------------------------------"
kubectl get service $APP_NAME -n $NAMESPACE
echo ""
echo "Service details:"
kubectl describe service $APP_NAME -n $NAMESPACE | grep -A 5 "Endpoints:"
echo ""

echo "3️⃣  Checking Ingress..."
echo "-------------------------------------------"
kubectl get ingress -n $NAMESPACE
echo ""
echo "Ingress details:"
kubectl describe ingress -n $NAMESPACE
echo ""

echo "4️⃣  Checking Ingress YAML..."
echo "-------------------------------------------"
kubectl get ingress -n $NAMESPACE -o yaml
echo ""

echo "5️⃣  Testing Service Directly..."
echo "-------------------------------------------"
CLUSTER_IP=$(kubectl get service $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
echo "Service Cluster IP: $CLUSTER_IP"
echo "Testing http://$CLUSTER_IP ..."
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -s http://$CLUSTER_IP || echo "Failed"
echo ""

echo "6️⃣  Checking Traefik Logs..."
echo "-------------------------------------------"
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=20
echo ""

echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="

# Made with Bob
