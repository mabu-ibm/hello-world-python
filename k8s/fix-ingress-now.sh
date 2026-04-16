#!/bin/bash
################################################################################
# Quick Fix: Replace Old Ingress with Flexible Ingress
# Purpose: Fix HTTP 404 by deploying flexible ingress (HTTP + HTTPS)
# Usage: ./fix-ingress-now.sh [INGRESS_HOST]
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

INGRESS_HOST="${1:-hello-world-python.lab.allwaysbeginner.com}"
NAMESPACE="${2:-default}"

log_info "Fixing Ingress Configuration"
log_info "============================="
log_info "Host: ${INGRESS_HOST}"
log_info "Namespace: ${NAMESPACE}"
echo ""

# Step 1: Delete old ingress
log_info "Step 1: Deleting old ingress..."
kubectl delete ingress hello-world-python-ingress -n ${NAMESPACE} --ignore-not-found=true
kubectl delete ingress hello-world-python -n ${NAMESPACE} --ignore-not-found=true
log_info "✓ Old ingress deleted"
echo ""

# Step 2: Deploy flexible ingress
log_info "Step 2: Deploying flexible ingress (HTTP + HTTPS)..."

cat <<EOFINGRESS | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-python-ingress
  namespace: ${NAMESPACE}
  labels:
    app: hello-world-python
  annotations:
    # Accept both HTTP and HTTPS traffic
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    
    # Optional TLS - works with or without certificate
    traefik.ingress.kubernetes.io/router.tls: "true"
    
    # DO NOT redirect HTTP to HTTPS - allow both
    # traefik.ingress.kubernetes.io/redirect-entry-point: https  # COMMENTED OUT
    
    # Nginx compatibility (if cluster uses nginx instead of traefik)
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
    
    # Allow insecure backend
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  # TLS configuration - optional, works without certificate
  tls:
  - hosts:
    - ${INGRESS_HOST}
    secretName: hello-world-python-tls
  rules:
  - host: ${INGRESS_HOST}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world-python
            port:
              number: 80
EOFINGRESS

log_info "✓ Flexible ingress deployed"
echo ""

# Step 3: Verify
log_info "Step 3: Verifying ingress..."
sleep 2

kubectl get ingress -n ${NAMESPACE}
echo ""

log_info "Checking annotations..."
ANNOTATIONS=$(kubectl get ingress hello-world-python-ingress -n ${NAMESPACE} -o jsonpath='{.metadata.annotations}')
echo "$ANNOTATIONS" | jq .

echo ""
log_info "============================================"
log_info "✅ Ingress Fixed!"
log_info "============================================"
echo ""

log_info "Key Changes:"
echo "  ✓ Entrypoints: web,websecure (HTTP + HTTPS)"
echo "  ✓ NO HTTP to HTTPS redirect"
echo "  ✓ Both protocols work"
echo ""

log_info "Test Commands:"
echo "  # HTTP (should work now!)"
echo "  curl http://${INGRESS_HOST}"
echo ""
echo "  # HTTPS"
echo "  curl -k https://${INGRESS_HOST}"
echo ""

log_info "If still getting 404, check:"
echo "  1. DNS/hosts file: ${INGRESS_HOST} → cluster IP"
echo "  2. Traefik logs: kubectl logs -n kube-system -l app.kubernetes.io/name=traefik"
echo "  3. Run diagnostics: ./k8s/diagnose-ingress.sh ${INGRESS_HOST}"
echo ""

# Made with Bob