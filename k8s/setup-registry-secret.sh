#!/bin/bash
################################################################################
# Setup Gitea Registry Secret in K3s
# Purpose: Create Docker registry secret for pulling images from Gitea
# Usage: ./setup-registry-secret.sh
################################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Setup Gitea Registry Secret for K3s"
echo ""

# Configuration
REGISTRY_SERVER="almabuild.lab.allwaysbeginner.com:3000"
SECRET_NAME="gitea-registry"
NAMESPACE="default"

# Get credentials
read -p "Enter your Gitea username: " GITEA_USER
read -sp "Enter your Gitea password or token: " GITEA_PASS
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if secret already exists
if kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} &> /dev/null; then
    log_warn "Secret ${SECRET_NAME} already exists in namespace ${NAMESPACE}"
    read -p "Do you want to delete and recreate it? (y/N): " RECREATE
    if [[ "$RECREATE" =~ ^[Yy]$ ]]; then
        log_info "Deleting existing secret..."
        kubectl delete secret ${SECRET_NAME} -n ${NAMESPACE}
    else
        log_info "Keeping existing secret"
        exit 0
    fi
fi

# Create secret
log_info "Creating Docker registry secret..."
kubectl create secret docker-registry ${SECRET_NAME} \
  --docker-server=${REGISTRY_SERVER} \
  --docker-username=${GITEA_USER} \
  --docker-password=${GITEA_PASS} \
  --docker-email=${GITEA_USER}@example.com \
  --namespace=${NAMESPACE}

if [ $? -eq 0 ]; then
    log_info "✓ Secret ${SECRET_NAME} created successfully"
else
    log_error "Failed to create secret"
    exit 1
fi

# Verify secret
log_info "Verifying secret..."
kubectl get secret ${SECRET_NAME} -n ${NAMESPACE}

log_info ""
log_info "=========================================="
log_info "Registry Secret Setup Complete!"
log_info "=========================================="
log_info "Secret name: ${SECRET_NAME}"
log_info "Namespace: ${NAMESPACE}"
log_info "Registry: ${REGISTRY_SERVER}"
log_info ""
log_info "You can now deploy applications that pull from Gitea registry"
log_info "Make sure your deployment uses: imagePullSecrets: - name: ${SECRET_NAME}"
log_info "=========================================="

# Made with Bob