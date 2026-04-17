#!/bin/bash
# Quick Fix: Remove Network Policy (Temporary Solution)
# This immediately resolves the Bad Gateway issue by removing the blocking network policy

set -e

echo "=========================================="
echo "Quick Fix: Remove Network Policy"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}WARNING:${NC} This removes the network policy entirely."
echo "This is a quick fix for testing. For production, use fix-network-policy-traefik.sh"
echo "to create a proper policy that allows Traefik access."
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo -e "${YELLOW}Step 1: Removing network policy...${NC}"
kubectl delete networkpolicy hello-world-python-netpol -n default
echo -e "${GREEN}✓ Network policy removed${NC}"
echo ""

echo -e "${YELLOW}Step 2: Waiting for changes to take effect...${NC}"
sleep 3
echo ""

echo -e "${YELLOW}Step 3: Testing ingress access...${NC}"
echo "Testing: curl -s -H 'Host: almak3s' http://192.168.8.31/health"
if curl -s -H 'Host: almak3s' http://192.168.8.31/health | grep -q "healthy"; then
    echo -e "${GREEN}✓ SUCCESS! Application is now accessible!${NC}"
else
    echo -e "${RED}✗ Still failing. There may be other issues.${NC}"
fi
echo ""

echo "=========================================="
echo "Fix Complete!"
echo "=========================================="
echo ""
echo "Your application should now be accessible at:"
echo "  http://almak3s"
echo "  http://192.168.8.31 (with Host: almak3s header)"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC}"
echo "Network policy has been removed. For production environments,"
echo "run fix-network-policy-traefik.sh to create a proper policy"
echo "that allows Traefik while maintaining security."
echo ""

# Made with Bob
