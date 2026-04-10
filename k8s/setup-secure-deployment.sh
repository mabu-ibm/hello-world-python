#!/bin/bash

# Setup Secure Deployment for Hello World Python
# This script implements security best practices for Kubernetes deployment

set -e

echo "=========================================="
echo "Secure Deployment Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on K3s host
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please run this on almak3s or configure kubectl.${NC}"
    exit 1
fi

echo "Step 1: Checking current deployment..."
if kubectl get deployment hello-world-python &> /dev/null; then
    echo -e "${YELLOW}Warning: Existing deployment found.${NC}"
    read -p "Do you want to replace it with secure deployment? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing deployment..."
        kubectl delete deployment hello-world-python
        kubectl delete service hello-world-python
        echo -e "${GREEN}✓ Existing deployment removed${NC}"
    else
        echo "Exiting without changes."
        exit 0
    fi
fi

echo ""
echo "Step 2: Creating secure deployment..."
kubectl apply -f deployment-secure.yaml
echo -e "${GREEN}✓ Secure deployment created${NC}"

echo ""
echo "Step 3: Creating network policy..."
kubectl apply -f network-policy.yaml
echo -e "${GREEN}✓ Network policy applied${NC}"

echo ""
echo "Step 4: Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=hello-world-python --timeout=120s
echo -e "${GREEN}✓ Pods are ready${NC}"

echo ""
echo "Step 5: Verifying security configuration..."

# Check security context
echo -n "  - Checking pod security context... "
POD_SECURITY=$(kubectl get pod -l app=hello-world-python -o jsonpath='{.items[0].spec.securityContext.runAsNonRoot}')
if [ "$POD_SECURITY" == "true" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Check container security context
echo -n "  - Checking container security context... "
CONTAINER_SECURITY=$(kubectl get pod -l app=hello-world-python -o jsonpath='{.items[0].spec.containers[0].securityContext.readOnlyRootFilesystem}')
if [ "$CONTAINER_SECURITY" == "true" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Check service account
echo -n "  - Checking service account... "
SERVICE_ACCOUNT=$(kubectl get pod -l app=hello-world-python -o jsonpath='{.items[0].spec.serviceAccountName}')
if [ "$SERVICE_ACCOUNT" == "hello-world-python" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Check network policy
echo -n "  - Checking network policy... "
if kubectl get networkpolicy hello-world-python-netpol &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo ""
echo "Step 6: Testing application..."
POD_NAME=$(kubectl get pod -l app=hello-world-python -o jsonpath='{.items[0].metadata.name}')

# Test health endpoint
echo -n "  - Testing health endpoint... "
if kubectl exec $POD_NAME -- curl -s http://localhost:8080/health > /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Test read-only filesystem
echo -n "  - Testing read-only filesystem... "
if kubectl exec $POD_NAME -- touch /test 2>&1 | grep -q "Read-only file system"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Test non-root user
echo -n "  - Testing non-root user... "
USER_ID=$(kubectl exec $POD_NAME -- id -u)
if [ "$USER_ID" == "1000" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo ""
echo "=========================================="
echo "Deployment Information"
echo "=========================================="
echo ""

# Get service info
SERVICE_IP=$(kubectl get service hello-world-python -o jsonpath='{.spec.clusterIP}')
echo "Service ClusterIP: $SERVICE_IP"

# Get pod info
echo ""
echo "Pods:"
kubectl get pods -l app=hello-world-python

echo ""
echo "Resources:"
kubectl describe pod -l app=hello-world-python | grep -A 5 "Limits:"

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Test the application:"
echo "   kubectl port-forward service/hello-world-python 8080:80"
echo "   curl http://localhost:8080/health"
echo ""
echo "2. Setup TLS/HTTPS (optional):"
echo "   - Install Traefik ingress controller"
echo "   - Generate TLS certificate"
echo "   - Apply ingress-secure.yaml"
echo ""
echo "3. Enable secrets encryption at rest:"
echo "   - See docs/SECURITY_HARDENING_GUIDE.md"
echo ""
echo "4. Run security audit:"
echo "   kubectl get pod -l app=hello-world-python -o yaml | kubesec scan -"
echo ""
echo -e "${GREEN}Secure deployment complete!${NC}"

# Made with Bob
