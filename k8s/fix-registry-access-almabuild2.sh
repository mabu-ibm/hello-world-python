#!/bin/bash
# Fix Registry Access for almabuild2
# This script configures Kubernetes to pull images from the new almabuild2 registry

set -e

echo "=========================================="
echo "Fix Registry Access for almabuild2"
echo "=========================================="

# Configuration
# Note: Gitea runs natively and registry is on port 3000
REGISTRY_HOST="${REGISTRY_HOST:-almabuild2:3000}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-manfred}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD}"
NAMESPACE="${NAMESPACE:-default}"
SECRET_NAME="registry-credentials"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if password is provided
if [ -z "$REGISTRY_PASSWORD" ]; then
    echo -e "${RED}Error: REGISTRY_PASSWORD environment variable is required${NC}"
    echo "Usage: REGISTRY_PASSWORD='your-password' ./fix-registry-access-almabuild2.sh"
    exit 1
fi

echo -e "${YELLOW}Step 1: Testing Gitea registry connectivity from this machine...${NC}"
echo "Note: Gitea runs natively, registry is on port 3000"

# Test Gitea web interface first
if curl -s http://almabuild2:3000 | grep -q "Gitea"; then
    echo -e "${GREEN}✓ Gitea is accessible${NC}"
else
    echo -e "${RED}✗ Cannot reach Gitea at almabuild2:3000${NC}"
    echo "Please check:"
    echo "  1. Gitea is running: ssh almabuild2 'sudo systemctl status gitea'"
    echo "  2. Firewall allows port 3000: ssh almabuild2 'sudo firewall-cmd --list-ports'"
    echo "  3. DNS/hosts file has correct entry for almabuild2"
    exit 1
fi

# Test registry endpoint
if curl -s http://${REGISTRY_HOST}/v2/ 2>/dev/null; then
    echo -e "${GREEN}✓ Registry endpoint is accessible${NC}"
    REGISTRY_URL="http://${REGISTRY_HOST}"
else
    echo -e "${YELLOW}⚠ Registry endpoint returned authentication required (this is normal)${NC}"
    REGISTRY_URL="http://${REGISTRY_HOST}"
fi

echo -e "\n${YELLOW}Step 2: Testing Docker login...${NC}"
if echo "$REGISTRY_PASSWORD" | docker login ${REGISTRY_HOST} --username ${REGISTRY_USERNAME} --password-stdin 2>/dev/null; then
    echo -e "${GREEN}✓ Docker login successful${NC}"
else
    echo -e "${RED}✗ Docker login failed${NC}"
    echo "Please verify credentials"
    exit 1
fi

echo -e "\n${YELLOW}Step 3: Checking if secret exists in Kubernetes...${NC}"
if kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} &>/dev/null; then
    echo -e "${YELLOW}Secret exists, deleting old secret...${NC}"
    kubectl delete secret ${SECRET_NAME} -n ${NAMESPACE}
fi

echo -e "\n${YELLOW}Step 4: Creating Kubernetes registry secret...${NC}"
kubectl create secret docker-registry ${SECRET_NAME} \
    --docker-server=${REGISTRY_HOST} \
    --docker-username=${REGISTRY_USERNAME} \
    --docker-password=${REGISTRY_PASSWORD} \
    --namespace=${NAMESPACE}

echo -e "${GREEN}✓ Secret created successfully${NC}"

echo -e "\n${YELLOW}Step 5: Verifying secret...${NC}"
kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o yaml | grep -A 5 "data:"
echo -e "${GREEN}✓ Secret verified${NC}"

echo -e "\n${YELLOW}Step 6: Checking deployment configuration...${NC}"
if kubectl get deployment hello-world-python -n ${NAMESPACE} &>/dev/null; then
    echo "Current deployment image:"
    kubectl get deployment hello-world-python -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].image}'
    echo ""
    
    echo "Current imagePullSecrets:"
    kubectl get deployment hello-world-python -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.imagePullSecrets}'
    echo ""
    
    # Check if imagePullSecrets is configured
    if ! kubectl get deployment hello-world-python -n ${NAMESPACE} -o yaml | grep -q "imagePullSecrets"; then
        echo -e "${YELLOW}⚠ Deployment doesn't have imagePullSecrets configured${NC}"
        echo -e "${YELLOW}Patching deployment...${NC}"
        
        kubectl patch deployment hello-world-python -n ${NAMESPACE} -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"'${SECRET_NAME}'"}]}}}}'
        
        echo -e "${GREEN}✓ Deployment patched${NC}"
    else
        echo -e "${GREEN}✓ Deployment already has imagePullSecrets${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Deployment not found, will be created by workflow${NC}"
fi

echo -e "\n${YELLOW}Step 7: Testing image pull from Kubernetes node...${NC}"
echo "Getting a node to test..."
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Testing on node: $NODE"

# Create a test pod to verify image pull
echo "Creating test pod with image: ${REGISTRY_HOST}/manfred/hello-world-python:latest"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: registry-test-pod
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: test
    image: ${REGISTRY_HOST}/manfred/hello-world-python:latest
    command: ["sleep", "30"]
  imagePullSecrets:
  - name: ${SECRET_NAME}
  restartPolicy: Never
EOF

echo "Waiting for pod to start (or fail)..."
sleep 5

POD_STATUS=$(kubectl get pod registry-test-pod -n ${NAMESPACE} -o jsonpath='{.status.phase}')
if [ "$POD_STATUS" = "Running" ] || [ "$POD_STATUS" = "Succeeded" ]; then
    echo -e "${GREEN}✓ Image pull successful!${NC}"
    kubectl delete pod registry-test-pod -n ${NAMESPACE}
else
    echo -e "${RED}✗ Image pull failed${NC}"
    echo "Pod status: $POD_STATUS"
    echo -e "\n${YELLOW}Pod events:${NC}"
    kubectl describe pod registry-test-pod -n ${NAMESPACE} | tail -20
    
    echo -e "\n${YELLOW}Cleaning up test pod...${NC}"
    kubectl delete pod registry-test-pod -n ${NAMESPACE} --force --grace-period=0 2>/dev/null || true
    
    echo -e "\n${RED}Troubleshooting steps:${NC}"
    echo "1. Check if nodes can reach Gitea registry:"
    echo "   kubectl run test --rm -it --image=busybox --restart=Never -- wget -O- http://${REGISTRY_HOST}/v2/"
    echo ""
    echo "2. Check if registry is configured for insecure access on nodes:"
    echo "   ssh <node> 'cat /etc/docker/daemon.json'"
    echo "   Should contain: \"insecure-registries\": [\"${REGISTRY_HOST}\"]"
    echo ""
    echo "3. Verify Gitea is running on almabuild2:"
    echo "   ssh almabuild2 'sudo systemctl status gitea'"
    echo ""
    echo "4. Check firewall on almabuild2:"
    echo "   ssh almabuild2 'sudo firewall-cmd --list-ports | grep 3000'"
    echo ""
    echo "5. Restart Docker on K8s nodes after config change:"
    echo "   ssh <node> 'sudo systemctl restart docker'"
    exit 1
fi

echo -e "\n${GREEN}=========================================="
echo "✓ Registry access configured successfully!"
echo "==========================================${NC}"
echo ""
echo "Summary:"
echo "  Registry: ${REGISTRY_HOST}"
echo "  Secret: ${SECRET_NAME}"
echo "  Namespace: ${NAMESPACE}"
echo ""
echo "Next steps:"
echo "  1. Update deployment.yaml to use imagePullSecrets"
echo "  2. Update image reference to: ${REGISTRY_HOST}/manfred/hello-world-python:latest"
echo "  3. Update Gitea secrets if using workflows:"
echo "     - GIT_REGISTRY: ${REGISTRY_HOST}"
echo "  4. Deploy: kubectl apply -f k8s/deployment.yaml"
echo ""
echo "To verify deployment:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo "  kubectl describe pod <pod-name> -n ${NAMESPACE}"
echo ""
echo "Important: Gitea registry uses port 3000, not 5000!"

# Made with Bob
