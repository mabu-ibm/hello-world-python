#!/bin/bash
################################################################################
# Traefik Routing Diagnostics
# Purpose: Check why Traefik returns 404 despite correct ingress
# Usage: ./check-traefik-routing.sh [INGRESS_HOST]
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

INGRESS_HOST="${1:-hello-world-python.lab.allwaysbeginner.com}"

log_info "Traefik Routing Diagnostics"
log_info "============================"
echo ""

# Step 1: Check Traefik logs for routing
log_step "1. Checking Traefik logs for routing errors..."
echo ""
log_info "Recent Traefik logs:"
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50 | grep -i "hello-world\|error\|404" || echo "No relevant logs found"
echo ""

# Step 2: Check if Traefik sees the ingress
log_step "2. Checking Traefik configuration..."
TRAEFIK_POD=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.name}')
log_info "Traefik pod: $TRAEFIK_POD"
echo ""

# Step 3: Test with curl verbose
log_step "3. Testing HTTP request with verbose output..."
echo ""
log_info "Testing: curl -v http://${INGRESS_HOST}"
curl -v http://${INGRESS_HOST} 2>&1 | head -30 || true
echo ""

# Step 4: Test with IP and Host header
log_step "4. Testing with IP and Host header..."
CLUSTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo ""
log_info "Testing: curl -v http://${CLUSTER_IP} -H 'Host: ${INGRESS_HOST}'"
curl -v http://${CLUSTER_IP} -H "Host: ${INGRESS_HOST}" 2>&1 | head -30 || true
echo ""

# Step 5: Check /etc/hosts
log_step "5. Checking /etc/hosts configuration..."
if grep -q "${INGRESS_HOST}" /etc/hosts 2>/dev/null; then
    log_info "✓ /etc/hosts entry exists:"
    grep "${INGRESS_HOST}" /etc/hosts
else
    log_warn "/etc/hosts entry NOT found"
    log_info "Add this line to /etc/hosts:"
    echo "  ${CLUSTER_IP}  ${INGRESS_HOST}"
fi
echo ""

# Step 6: Check Traefik IngressRoute (if using CRD)
log_step "6. Checking for Traefik IngressRoute CRDs..."
if kubectl get ingressroute -n default &>/dev/null; then
    kubectl get ingressroute -n default
else
    log_info "No IngressRoute CRDs found (using standard Ingress)"
fi
echo ""

# Step 7: Restart Traefik
log_step "7. Restarting Traefik to reload configuration..."
read -p "Restart Traefik? (y/N): " RESTART
if [[ "$RESTART" =~ ^[Yy]$ ]]; then
    kubectl rollout restart deployment traefik -n kube-system 2>/dev/null || \
    kubectl delete pod -n kube-system -l app.kubernetes.io/name=traefik
    
    log_info "Waiting for Traefik to restart..."
    sleep 10
    
    kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
    
    log_info "Testing again after restart..."
    sleep 5
    curl -v http://${INGRESS_HOST} 2>&1 | head -20 || true
fi
echo ""

# Step 8: Check Traefik service
log_step "8. Checking Traefik service..."
kubectl get svc -n kube-system traefik
echo ""

# Step 9: Recommendations
log_info "============================================"
log_info "Troubleshooting Recommendations"
log_info "============================================"
echo ""

log_info "1. Check if DNS/hosts resolves correctly:"
echo "   ping ${INGRESS_HOST}"
echo ""

log_info "2. Check Traefik dashboard (if enabled):"
echo "   kubectl port-forward -n kube-system svc/traefik 9000:9000"
echo "   Open: http://localhost:9000/dashboard/"
echo ""

log_info "3. Watch Traefik logs in real-time:"
echo "   kubectl logs -n kube-system -l app.kubernetes.io/name=traefik -f"
echo ""

log_info "4. Test from within cluster:"
echo "   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \\"
echo "     curl -v http://hello-world-python.default.svc.cluster.local"
echo ""

log_info "5. Check if Traefik is using correct entrypoints:"
echo "   kubectl get deployment traefik -n kube-system -o yaml | grep -A 10 args"
echo ""

log_info "6. Verify ingress class:"
echo "   kubectl get ingressclass"
echo ""

# Made with Bob