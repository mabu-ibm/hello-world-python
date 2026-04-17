#!/bin/bash
# Fix Network Policy to Allow Traefik Access
# This resolves the Bad Gateway issue caused by network policy blocking Traefik

set -e

echo "=========================================="
echo "Network Policy Fix for Traefik Access"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Current Issue:${NC}"
echo "Network policy 'hello-world-python-netpol' is blocking Traefik ingress controller"
echo "from accessing the application pods, causing 502 Bad Gateway errors."
echo ""

echo -e "${YELLOW}Step 1: Checking current network policy...${NC}"
kubectl get networkpolicy hello-world-python-netpol -n default -o yaml
echo ""

echo -e "${YELLOW}Step 2: Deleting restrictive network policy...${NC}"
kubectl delete networkpolicy hello-world-python-netpol -n default
echo -e "${GREEN}✓ Old network policy deleted${NC}"
echo ""

echo -e "${YELLOW}Step 3: Creating new network policy that allows Traefik...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: hello-world-python-netpol
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: hello-world-python
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Allow traffic from Traefik ingress controller
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          app.kubernetes.io/name: traefik
    ports:
    - protocol: TCP
      port: 8080
  # Allow traffic from same namespace (for service mesh)
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8080
  # Allow traffic from ingress controller namespace
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # Allow all egress (for external API calls, DNS, etc.)
  - {}
EOF
echo -e "${GREEN}✓ New network policy created with Traefik access${NC}"
echo ""

echo -e "${YELLOW}Step 4: Waiting for policy to take effect...${NC}"
sleep 3
echo ""

echo -e "${YELLOW}Step 5: Testing ingress access...${NC}"
echo "Testing: curl -s -H 'Host: almak3s' http://192.168.8.31/health"
if curl -s -H 'Host: almak3s' http://192.168.8.31/health | grep -q "healthy"; then
    echo -e "${GREEN}✓ SUCCESS! Ingress access now working!${NC}"
    echo ""
    echo "Testing full page..."
    curl -s -H 'Host: almak3s' http://192.168.8.31/ | head -20
else
    echo -e "${RED}✗ Still failing. Checking additional issues...${NC}"
    echo ""
    echo "Checking Traefik pod labels:"
    kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --show-labels
    echo ""
    echo "You may need to adjust the network policy podSelector to match your Traefik labels."
fi
echo ""

echo "=========================================="
echo "Fix Complete!"
echo "=========================================="
echo ""
echo "The network policy has been updated to allow:"
echo "1. Traffic from Traefik ingress controller (kube-system namespace)"
echo "2. Traffic from pods in the same namespace"
echo "3. All egress traffic"
echo ""
echo "Test your application:"
echo "  Browser: http://almak3s"
echo "  Curl: curl -H 'Host: almak3s' http://192.168.8.31/"
echo ""
echo "If still not working, check Traefik pod labels:"
echo "  kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --show-labels"
echo ""

# Made with Bob
