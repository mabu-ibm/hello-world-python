#!/bin/bash
# Quick Fix Script for Bad Gateway Issues
# Run this on the almak3s machine

set -e

echo "=========================================="
echo "Bad Gateway Quick Fix Script"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Step 1: Checking current ingress configuration...${NC}"
kubectl get ingress hello-world-python -n default -o yaml | grep -A 5 "spec:"
echo ""

echo -e "${YELLOW}Step 2: Deleting old ingress...${NC}"
kubectl delete ingress hello-world-python -n default --ignore-not-found=true
echo -e "${GREEN}✓ Old ingress deleted${NC}"
echo ""

echo -e "${YELLOW}Step 3: Creating new ingress with correct configuration...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-python
  namespace: default
  labels:
    app: hello-world-python
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
  - host: almak3s
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world-python
            port:
              number: 80
EOF
echo -e "${GREEN}✓ New ingress created${NC}"
echo ""

echo -e "${YELLOW}Step 4: Waiting for ingress to be ready...${NC}"
sleep 5
kubectl get ingress hello-world-python -n default
echo ""

echo -e "${YELLOW}Step 5: Testing service endpoints...${NC}"
kubectl get endpoints hello-world-python -n default
echo ""

echo -e "${YELLOW}Step 6: Testing NodePort access...${NC}"
NODE_PORT=$(kubectl get svc hello-world-python -n default -o jsonpath='{.spec.ports[0].nodePort}')
echo "NodePort: $NODE_PORT"
echo "Testing: curl -s http://localhost:$NODE_PORT/health"
if curl -s http://localhost:$NODE_PORT/health | grep -q "healthy"; then
    echo -e "${GREEN}✓ NodePort access working!${NC}"
else
    echo -e "${RED}✗ NodePort access failed${NC}"
fi
echo ""

echo -e "${YELLOW}Step 7: Testing ingress access...${NC}"
echo "Testing: curl -s -H 'Host: almak3s' http://192.168.8.31/health"
if curl -s -H 'Host: almak3s' http://192.168.8.31/health | grep -q "healthy"; then
    echo -e "${GREEN}✓ Ingress access working!${NC}"
else
    echo -e "${RED}✗ Ingress access failed - checking Traefik logs...${NC}"
    kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=10
fi
echo ""

echo -e "${YELLOW}Step 8: Checking Traefik routing...${NC}"
kubectl get ingressroute -A 2>/dev/null || echo "No IngressRoutes found (this is normal for standard Ingress)"
echo ""

echo "=========================================="
echo "Fix Complete!"
echo "=========================================="
echo ""
echo "Access your application:"
echo "1. Via browser: http://almak3s (if DNS is configured)"
echo "2. Via IP: http://192.168.8.31 (with Host header)"
echo "3. Via NodePort: http://192.168.8.31:$NODE_PORT"
echo ""
echo "Test commands:"
echo "  curl -H 'Host: almak3s' http://192.168.8.31/"
echo "  curl http://192.168.8.31:$NODE_PORT/"
echo ""

# Made with Bob
