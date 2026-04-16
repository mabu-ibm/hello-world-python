#!/bin/bash
################################################################################
# Flexible Deployment Script for Hello World Python
# Purpose: Deploy to any K3s cluster with HTTP and HTTPS support
# Usage: ./deploy-flexible.sh [INGRESS_HOST] [IMAGE_REGISTRY] [IMAGE_TAG]
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

log_info "Flexible K3s Deployment Script"
log_info "==============================="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration with defaults
INGRESS_HOST="${1:-hello-world-python.lab.allwaysbeginner.com}"
IMAGE_REGISTRY="${2:-almabuild2.lab.allwaysbeginner.com:5000}"
IMAGE_REPOSITORY="${3:-hello-world-python}"
IMAGE_TAG="${4:-latest}"
NAMESPACE="${5:-default}"

log_info "Deployment Configuration:"
log_info "  Ingress Host: ${INGRESS_HOST}"
log_info "  Image Registry: ${IMAGE_REGISTRY}"
log_info "  Image Repository: ${IMAGE_REPOSITORY}"
log_info "  Image Tag: ${IMAGE_TAG}"
log_info "  Namespace: ${NAMESPACE}"
echo ""

# Step 1: Check kubectl
log_step "1. Checking kubectl connection..."
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    log_info "Make sure KUBECONFIG is set or ~/.kube/config exists"
    exit 1
fi

CLUSTER_NAME=$(kubectl config current-context)
log_info "✓ Connected to cluster: ${CLUSTER_NAME}"
echo ""

# Step 2: Create namespace if it doesn't exist
log_step "2. Ensuring namespace exists..."
if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
    kubectl create namespace ${NAMESPACE}
    log_info "✓ Namespace created: ${NAMESPACE}"
else
    log_info "✓ Namespace exists: ${NAMESPACE}"
fi
echo ""

# Step 3: Deploy application
log_step "3. Deploying application..."
FULL_IMAGE="${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}"

# Replace variables in deployment.yaml
sed -e "s|\${IMAGE_REGISTRY}|${IMAGE_REGISTRY}|g" \
    -e "s|\${IMAGE_REPOSITORY}|${IMAGE_REPOSITORY}|g" \
    -e "s|\${IMAGE_TAG}|${IMAGE_TAG}|g" \
    -e "s|namespace: default|namespace: ${NAMESPACE}|g" \
    "${SCRIPT_DIR}/deployment.yaml" | kubectl apply -f -

log_info "✓ Deployment applied"
echo ""

# Step 4: Wait for deployment
log_step "4. Waiting for deployment to be ready..."
if kubectl rollout status deployment/hello-world-python -n ${NAMESPACE} --timeout=5m; then
    log_info "✓ Deployment is ready"
else
    log_error "Deployment failed or timed out"
    kubectl get pods -n ${NAMESPACE} -l app=hello-world-python
    exit 1
fi
echo ""

# Step 5: Create TLS certificate (self-signed)
log_step "5. Setting up TLS certificate..."
if kubectl get secret hello-world-python-tls -n ${NAMESPACE} &> /dev/null; then
    log_info "✓ TLS secret already exists"
else
    log_info "Creating self-signed TLS certificate for: ${INGRESS_HOST}"
    
    # Create temporary directory for certificates
    TMP_DIR=$(mktemp -d)
    
    # Generate self-signed certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${TMP_DIR}/tls.key" \
        -out "${TMP_DIR}/tls.crt" \
        -subj "/CN=${INGRESS_HOST}/O=Hello World Python/C=US" \
        2>/dev/null
    
    # Create Kubernetes TLS secret
    kubectl create secret tls hello-world-python-tls \
        --cert="${TMP_DIR}/tls.crt" \
        --key="${TMP_DIR}/tls.key" \
        -n ${NAMESPACE}
    
    # Cleanup
    rm -rf "${TMP_DIR}"
    
    log_info "✓ TLS certificate created"
fi
echo ""

# Step 6: Deploy flexible ingress
log_step "6. Deploying flexible ingress (HTTP + HTTPS)..."

# Replace variables in ingress-flexible.yaml
sed -e "s|\${INGRESS_HOST}|${INGRESS_HOST}|g" \
    -e "s|namespace: default|namespace: ${NAMESPACE}|g" \
    "${SCRIPT_DIR}/ingress-flexible.yaml" | kubectl apply -f -

log_info "✓ Ingress deployed"
echo ""

# Step 7: Get deployment information
log_step "7. Deployment Information"
echo ""

log_info "Pods:"
kubectl get pods -n ${NAMESPACE} -l app=hello-world-python

echo ""
log_info "Service:"
kubectl get service hello-world-python -n ${NAMESPACE}

echo ""
log_info "Ingress:"
kubectl get ingress hello-world-python -n ${NAMESPACE}

echo ""
log_info "============================================"
log_info "Deployment Complete!"
log_info "============================================"
echo ""

# Get cluster IP for /etc/hosts
CLUSTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

log_info "Access URLs:"
log_info "  HTTP:  http://${INGRESS_HOST}"
log_info "  HTTPS: https://${INGRESS_HOST} (self-signed cert)"
echo ""

log_info "Add to /etc/hosts on your machine:"
echo "  ${CLUSTER_IP}  ${INGRESS_HOST}"
echo ""

log_info "Test from command line:"
echo "  # HTTP"
echo "  curl http://${INGRESS_HOST}"
echo ""
echo "  # HTTPS (ignore self-signed cert warning)"
echo "  curl -k https://${INGRESS_HOST}"
echo ""

log_info "Useful Commands:"
echo "  # View logs"
echo "  kubectl logs -n ${NAMESPACE} -l app=hello-world-python -f"
echo ""
echo "  # Check pod status"
echo "  kubectl get pods -n ${NAMESPACE} -l app=hello-world-python"
echo ""
echo "  # Restart deployment"
echo "  kubectl rollout restart deployment/hello-world-python -n ${NAMESPACE}"
echo ""
echo "  # Delete deployment"
echo "  kubectl delete -f ${SCRIPT_DIR}/deployment.yaml"
echo "  kubectl delete -f ${SCRIPT_DIR}/ingress-flexible.yaml"
echo ""

log_info "============================================"

# Made with Bob