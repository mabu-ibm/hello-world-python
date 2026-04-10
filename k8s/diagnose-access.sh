#!/bin/bash

# Diagnose K3s App Access Issues
# Run this on your K3s machine (almak3s)

set -e

echo "=========================================="
echo "K3s Hello World Python - Access Diagnostics"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi

echo "1️⃣  Checking Deployment Status..."
echo "-------------------------------------------"
DEPLOYMENT=$(kubectl get deployment hello-world-python -n default 2>/dev/null || echo "NOT_FOUND")
if [ "$DEPLOYMENT" = "NOT_FOUND" ]; then
    echo -e "${RED}❌ Deployment not found${NC}"
    echo ""
    echo "To deploy:"
    echo "  kubectl apply -f k8s/deployment.yaml"
    exit 1
else
    kubectl get deployment hello-world-python -n default
    echo -e "${GREEN}✅ Deployment exists${NC}"
fi
echo ""

echo "2️⃣  Checking Pod Status..."
echo "-------------------------------------------"
PODS=$(kubectl get pods -n default -l app=hello-world-python --no-headers 2>/dev/null | wc -l)
if [ "$PODS" -eq 0 ]; then
    echo -e "${RED}❌ No pods found${NC}"
    echo ""
    echo "Check deployment:"
    echo "  kubectl describe deployment hello-world-python -n default"
    exit 1
fi

kubectl get pods -n default -l app=hello-world-python

RUNNING=$(kubectl get pods -n default -l app=hello-world-python --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$RUNNING" -eq 0 ]; then
    echo -e "${RED}❌ No pods in Running state${NC}"
    echo ""
    echo "Check pod details:"
    echo "  kubectl describe pod -l app=hello-world-python -n default"
    echo ""
    echo "Check pod logs:"
    echo "  kubectl logs -l app=hello-world-python -n default"
    exit 1
else
    echo -e "${GREEN}✅ $RUNNING pod(s) running${NC}"
fi
echo ""

echo "3️⃣  Checking Service..."
echo "-------------------------------------------"
SERVICE=$(kubectl get service hello-world-python -n default 2>/dev/null || echo "NOT_FOUND")
if [ "$SERVICE" = "NOT_FOUND" ]; then
    echo -e "${RED}❌ Service not found${NC}"
    exit 1
fi

kubectl get service hello-world-python -n default
echo -e "${GREEN}✅ Service exists${NC}"
echo ""

echo "4️⃣  Checking NodePort Configuration..."
echo "-------------------------------------------"
NODE_PORT=$(kubectl get service hello-world-python -n default -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
SERVICE_TYPE=$(kubectl get service hello-world-python -n default -o jsonpath='{.spec.type}' 2>/dev/null)

echo "Service Type: $SERVICE_TYPE"
echo "NodePort: $NODE_PORT"

if [ "$SERVICE_TYPE" != "NodePort" ]; then
    echo -e "${RED}❌ Service type is not NodePort${NC}"
    echo ""
    echo "Fix with:"
    echo "  kubectl delete service hello-world-python -n default"
    echo "  kubectl apply -f k8s/deployment.yaml"
    exit 1
fi

if [ -z "$NODE_PORT" ]; then
    echo -e "${RED}❌ NodePort not configured${NC}"
    exit 1
fi

if [ "$NODE_PORT" != "30080" ]; then
    echo -e "${YELLOW}⚠️  NodePort is $NODE_PORT (expected 30080)${NC}"
else
    echo -e "${GREEN}✅ NodePort correctly set to 30080${NC}"
fi
echo ""

echo "5️⃣  Checking if Port is Listening..."
echo "-------------------------------------------"
if sudo netstat -tulpn | grep -q ":$NODE_PORT"; then
    echo -e "${GREEN}✅ Port $NODE_PORT is listening${NC}"
    sudo netstat -tulpn | grep ":$NODE_PORT"
else
    echo -e "${RED}❌ Port $NODE_PORT is NOT listening${NC}"
    echo ""
    echo "This might be a K3s issue. Try restarting K3s:"
    echo "  sudo systemctl restart k3s"
fi
echo ""

echo "6️⃣  Testing Local Access..."
echo "-------------------------------------------"
echo "Testing http://localhost:$NODE_PORT ..."
if curl -s -f http://localhost:$NODE_PORT > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Local access works!${NC}"
    echo ""
    echo "Response preview:"
    curl -s http://localhost:$NODE_PORT | head -n 10
else
    echo -e "${RED}❌ Local access failed${NC}"
    echo ""
    echo "Check pod logs:"
    echo "  kubectl logs -l app=hello-world-python -n default --tail=50"
fi
echo ""

echo "7️⃣  Checking Firewall..."
echo "-------------------------------------------"
if command -v firewall-cmd &> /dev/null; then
    echo "Firewalld detected"
    if sudo firewall-cmd --list-ports | grep -q "$NODE_PORT/tcp"; then
        echo -e "${GREEN}✅ Port $NODE_PORT is open in firewall${NC}"
    else
        echo -e "${YELLOW}⚠️  Port $NODE_PORT not in firewall rules${NC}"
        echo ""
        echo "To open port:"
        echo "  sudo firewall-cmd --add-port=$NODE_PORT/tcp --permanent"
        echo "  sudo firewall-cmd --reload"
    fi
elif command -v ufw &> /dev/null; then
    echo "UFW detected"
    if sudo ufw status | grep -q "$NODE_PORT"; then
        echo -e "${GREEN}✅ Port $NODE_PORT is open in firewall${NC}"
    else
        echo -e "${YELLOW}⚠️  Port $NODE_PORT not in firewall rules${NC}"
        echo ""
        echo "To open port:"
        echo "  sudo ufw allow $NODE_PORT/tcp"
    fi
else
    echo "No firewall detected (or iptables only)"
fi
echo ""

echo "8️⃣  Node IP Addresses..."
echo "-------------------------------------------"
NODE_IPS=$(hostname -I)
echo "Available IPs: $NODE_IPS"
MAIN_IP=$(echo $NODE_IPS | awk '{print $1}')
echo "Primary IP: $MAIN_IP"
echo ""

echo "9️⃣  Recent Pod Logs..."
echo "-------------------------------------------"
kubectl logs -l app=hello-world-python -n default --tail=20 2>/dev/null || echo "No logs available"
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

if [ "$RUNNING" -gt 0 ] && [ "$SERVICE_TYPE" = "NodePort" ] && curl -s -f http://localhost:$NODE_PORT > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Application is running correctly!${NC}"
    echo ""
    echo "Access URLs:"
    echo "  Local:    http://localhost:$NODE_PORT"
    echo "  Internal: http://$MAIN_IP:$NODE_PORT"
    echo "  External: http://almak3s.lab.allwaysbeginner.com:$NODE_PORT"
    echo ""
    echo "If external access doesn't work:"
    echo "  1. Check firewall (see section 7 above)"
    echo "  2. Verify DNS resolves to $MAIN_IP"
    echo "  3. Check network connectivity from client"
else
    echo -e "${RED}❌ Application has issues${NC}"
    echo ""
    echo "Common fixes:"
    echo ""
    echo "1. Redeploy application:"
    echo "   kubectl delete -f k8s/deployment.yaml"
    echo "   kubectl apply -f k8s/deployment.yaml"
    echo ""
    echo "2. Check pod logs:"
    echo "   kubectl logs -l app=hello-world-python -n default"
    echo ""
    echo "3. Describe pod for errors:"
    echo "   kubectl describe pod -l app=hello-world-python -n default"
    echo ""
    echo "4. Restart K3s:"
    echo "   sudo systemctl restart k3s"
    echo ""
    echo "5. Open firewall port:"
    echo "   sudo firewall-cmd --add-port=$NODE_PORT/tcp --permanent"
    echo "   sudo firewall-cmd --reload"
fi

echo ""
echo "=========================================="
echo "For more help, see TROUBLESHOOTING_ACCESS.md"
echo "=========================================="

# Made with Bob
