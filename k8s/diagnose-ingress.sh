#!/bin/bash
################################################################################
# Ingress Diagnostics Script
# Purpose: Diagnose why ingress is returning 404
# Usage: ./diagnose-ingress.sh [INGRESS_HOST]
################################################################################

set -euo pipefail

# Colors
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
NAMESPACE="${2:-default}"

log_info "Ingress Diagnostics"
log_info "==================="
log_info "Host: ${INGRESS_HOST}"
log_info "Namespace: ${NAMESPACE}"
echo ""

# Step 1: Check if pods are running
log_step "1. Checking Pods"
PODS=$(kubectl get pods -n ${NAMESPACE} -l app=hello-world-python --no-headers 2>/dev/null || echo "")
if [ -z "$PODS" ]; then
    log_error "No pods found with label app=hello-world-python"
    log_info "Check if deployment exists:"
    echo "  kubectl get deployment -n ${NAMESPACE}"
    exit 1
fi

RUNNING_PODS=$(echo "$PODS" | grep -c "Running" || echo "0")
TOTAL_PODS=$(echo "$PODS" | wc -l)

if [ "$RUNNING_PODS" -eq 0 ]; then
    log_error "No pods are running ($RUNNING_PODS/$TOTAL_PODS)"
    echo "$PODS"
    echo ""
    log_info "Check pod logs:"
    echo "  kubectl logs -n ${NAMESPACE} -l app=hello-world-python"
    exit 1
else
    log_info "✓ Pods running: $RUNNING_PODS/$TOTAL_PODS"
    echo "$PODS"
fi
echo ""

# Step 2: Check service
log_step "2. Checking Service"
if ! kubectl get service hello-world-python -n ${NAMESPACE} &>/dev/null; then
    log_error "Service 'hello-world-python' not found in namespace ${NAMESPACE}"
    log_info "Available services:"
    kubectl get services -n ${NAMESPACE}
    exit 1
fi

SERVICE_INFO=$(kubectl get service hello-world-python -n ${NAMESPACE} -o wide)
log_info "✓ Service exists"
echo "$SERVICE_INFO"

# Check service endpoints
ENDPOINTS=$(kubectl get endpoints hello-world-python -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
if [ -z "$ENDPOINTS" ]; then
    log_error "Service has no endpoints (no pods selected)"
    log_info "Check service selector matches pod labels"
    echo ""
    echo "Service selector:"
    kubectl get service hello-world-python -n ${NAMESPACE} -o jsonpath='{.spec.selector}' | jq .
    echo ""
    echo "Pod labels:"
    kubectl get pods -n ${NAMESPACE} -l app=hello-world-python -o jsonpath='{.items[0].metadata.labels}' | jq .
    exit 1
else
    log_info "✓ Service endpoints: $ENDPOINTS"
fi
echo ""

# Step 3: Check ingress
log_step "3. Checking Ingress"
INGRESS_NAME=$(kubectl get ingress -n ${NAMESPACE} -o name 2>/dev/null | head -1 | cut -d'/' -f2)
if [ -z "$INGRESS_NAME" ]; then
    log_error "No ingress found in namespace ${NAMESPACE}"
    log_info "Create ingress with:"
    echo "  kubectl apply -f k8s/ingress-flexible.yaml"
    exit 1
fi

log_info "✓ Ingress found: $INGRESS_NAME"
kubectl get ingress ${INGRESS_NAME} -n ${NAMESPACE}
echo ""

# Check ingress details
log_info "Ingress Details:"
kubectl describe ingress ${INGRESS_NAME} -n ${NAMESPACE}
echo ""

# Step 4: Check ingress host configuration
log_step "4. Checking Ingress Host Configuration"
INGRESS_HOSTS=$(kubectl get ingress ${INGRESS_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.rules[*].host}')
if [ -z "$INGRESS_HOSTS" ]; then
    log_error "Ingress has no host rules configured"
    exit 1
fi

log_info "Configured hosts: $INGRESS_HOSTS"

if echo "$INGRESS_HOSTS" | grep -q "\${INGRESS_HOST}"; then
    log_error "Ingress still has variable placeholder: \${INGRESS_HOST}"
    log_info "The ingress was not properly templated. Redeploy with:"
    echo "  sed \"s/\\\${INGRESS_HOST}/${INGRESS_HOST}/g\" k8s/ingress-flexible.yaml | kubectl apply -f -"
    exit 1
fi

if ! echo "$INGRESS_HOSTS" | grep -q "$INGRESS_HOST"; then
    log_warn "Requested host '$INGRESS_HOST' not found in ingress"
    log_info "Ingress is configured for: $INGRESS_HOSTS"
    log_info "You're trying to access: $INGRESS_HOST"
    log_info "These must match!"
fi
echo ""

# Step 5: Check ingress controller
log_step "5. Checking Ingress Controller"
TRAEFIK_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null || echo "")
NGINX_PODS=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --no-headers 2>/dev/null || echo "")

if [ -n "$TRAEFIK_PODS" ]; then
    log_info "✓ Traefik ingress controller found"
    echo "$TRAEFIK_PODS"
elif [ -n "$NGINX_PODS" ]; then
    log_info "✓ Nginx ingress controller found"
    echo "$NGINX_PODS"
else
    log_error "No ingress controller found (neither Traefik nor Nginx)"
    log_info "K3s should have Traefik by default. Check with:"
    echo "  kubectl get pods -n kube-system | grep traefik"
    exit 1
fi
echo ""

# Step 6: Check ingress annotations
log_step "6. Checking Ingress Annotations"
ANNOTATIONS=$(kubectl get ingress ${INGRESS_NAME} -n ${NAMESPACE} -o jsonpath='{.metadata.annotations}')
log_info "Ingress annotations:"
echo "$ANNOTATIONS" | jq . 2>/dev/null || echo "$ANNOTATIONS"
echo ""

# Check for common issues
if echo "$ANNOTATIONS" | grep -q "redirect-entry-point.*https"; then
    log_warn "HTTP to HTTPS redirect is enabled - HTTP requests will redirect"
fi

ENTRYPOINTS=$(echo "$ANNOTATIONS" | jq -r '."traefik.ingress.kubernetes.io/router.entrypoints"' 2>/dev/null || echo "")
if [ -n "$ENTRYPOINTS" ] && [ "$ENTRYPOINTS" != "null" ]; then
    log_info "Traefik entrypoints: $ENTRYPOINTS"
    if ! echo "$ENTRYPOINTS" | grep -q "web"; then
        log_warn "HTTP entrypoint 'web' not configured - HTTP won't work"
    fi
    if ! echo "$ENTRYPOINTS" | grep -q "websecure"; then
        log_warn "HTTPS entrypoint 'websecure' not configured - HTTPS won't work"
    fi
fi
echo ""

# Step 7: Test service directly
log_step "7. Testing Service Directly"
POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=hello-world-python -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD_NAME" ]; then
    log_info "Testing pod directly: $POD_NAME"
    if kubectl exec -n ${NAMESPACE} ${POD_NAME} -- wget -q -O- http://localhost:8080 &>/dev/null; then
        log_info "✓ Pod responds on port 8080"
    else
        log_error "Pod does not respond on port 8080"
        log_info "Check if app is running inside pod"
    fi
    
    log_info "Testing service from within cluster..."
    kubectl run -it --rm debug --image=busybox --restart=Never -- \
        wget -q -O- http://hello-world-python.${NAMESPACE}.svc.cluster.local 2>/dev/null && \
        log_info "✓ Service responds within cluster" || \
        log_error "Service does not respond within cluster"
fi
echo ""

# Step 8: Check DNS resolution
log_step "8. Checking DNS Resolution"
if command -v nslookup &>/dev/null; then
    log_info "Resolving ${INGRESS_HOST}..."
    nslookup ${INGRESS_HOST} || log_warn "DNS resolution failed"
elif command -v dig &>/dev/null; then
    log_info "Resolving ${INGRESS_HOST}..."
    dig +short ${INGRESS_HOST} || log_warn "DNS resolution failed"
else
    log_warn "No DNS tools available (nslookup/dig)"
fi
echo ""

# Step 9: Get cluster IP
log_step "9. Cluster Access Information"
CLUSTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
if [ -n "$CLUSTER_IP" ]; then
    log_info "Cluster IP: $CLUSTER_IP"
    log_info "Add to /etc/hosts:"
    echo "  ${CLUSTER_IP}  ${INGRESS_HOST}"
fi
echo ""

# Step 10: Summary and recommendations
log_info "============================================"
log_info "Diagnostic Summary"
log_info "============================================"
echo ""

log_info "✅ Checklist:"
echo "  [ ] Pods are running"
echo "  [ ] Service exists and has endpoints"
echo "  [ ] Ingress exists and is configured"
echo "  [ ] Ingress host matches your request"
echo "  [ ] Ingress controller is running"
echo "  [ ] DNS resolves to cluster IP"
echo "  [ ] /etc/hosts entry exists (if using local DNS)"
echo ""

log_info "🧪 Test Commands:"
echo "  # Test HTTP"
echo "  curl -v http://${INGRESS_HOST}"
echo ""
echo "  # Test HTTPS"
echo "  curl -kv https://${INGRESS_HOST}"
echo ""
echo "  # Test with IP (bypass DNS)"
if [ -n "$CLUSTER_IP" ]; then
    echo "  curl -v http://${CLUSTER_IP} -H 'Host: ${INGRESS_HOST}'"
fi
echo ""

log_info "🔍 Debug Commands:"
echo "  # Check ingress logs (Traefik)"
echo "  kubectl logs -n kube-system -l app.kubernetes.io/name=traefik -f"
echo ""
echo "  # Check pod logs"
echo "  kubectl logs -n ${NAMESPACE} -l app=hello-world-python -f"
echo ""
echo "  # Describe ingress"
echo "  kubectl describe ingress ${INGRESS_NAME} -n ${NAMESPACE}"
echo ""

log_info "============================================"

# Made with Bob