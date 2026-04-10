#!/bin/bash
################################################################################
# Setup Remote kubectl Access from almabuild to almak3s
# Purpose: Configure kubectl on almabuild to manage almak3s K3s cluster
# Usage: Run on almabuild host
################################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

log_info "=========================================="
log_info "Setup Remote kubectl Access"
log_info "almabuild → almak3s"
log_info "=========================================="
echo ""

# Configuration
K3S_HOST="almak3s.lab.allwaysbeginner.com"
K3S_PORT="6443"
KUBECONFIG_DIR="$HOME/.kube"
KUBECONFIG_FILE="$KUBECONFIG_DIR/config"

log_step "Step 1: Install kubectl"

if command -v kubectl &> /dev/null; then
    log_info "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    log_info "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    log_info "✓ kubectl installed"
fi

log_step "Step 2: Get kubeconfig from almak3s"

log_info "You need to copy the kubeconfig from almak3s host"
log_info ""
log_info "On almak3s host, run:"
echo -e "${BLUE}sudo cat /etc/rancher/k3s/k3s.yaml${NC}"
log_info ""
read -p "Press Enter when you have the kubeconfig content ready..."

log_info "Creating kubeconfig directory..."
mkdir -p "$KUBECONFIG_DIR"

log_info "Please paste the kubeconfig content (Ctrl+D when done):"
cat > /tmp/k3s-config.yaml

log_step "Step 3: Update kubeconfig server address"

# Replace 127.0.0.1 with actual K3s host
sed "s/127.0.0.1/${K3S_HOST}/g" /tmp/k3s-config.yaml > "$KUBECONFIG_FILE"
chmod 600 "$KUBECONFIG_FILE"

log_info "✓ Kubeconfig saved to $KUBECONFIG_FILE"

log_step "Step 4: Test connection"

log_info "Testing connection to K3s cluster..."
if kubectl cluster-info &> /dev/null; then
    log_info "✓ Successfully connected to K3s cluster"
    kubectl cluster-info
    echo ""
    kubectl get nodes
else
    log_error "Failed to connect to K3s cluster"
    log_info "Check:"
    log_info "  1. Network connectivity: ping ${K3S_HOST}"
    log_info "  2. K3s API port: curl -k https://${K3S_HOST}:${K3S_PORT}"
    log_info "  3. Firewall rules on almak3s"
    exit 1
fi

log_step "Step 5: Setup for gitea-runner user"

log_info "Setting up kubectl for gitea-runner user..."

# Create .kube directory for gitea-runner
sudo mkdir -p /var/lib/gitea-runner/.kube

# Copy kubeconfig
sudo cp "$KUBECONFIG_FILE" /var/lib/gitea-runner/.kube/config

# Set ownership
sudo chown -R gitea-runner:gitea-runner /var/lib/gitea-runner/.kube
sudo chmod 600 /var/lib/gitea-runner/.kube/config

log_info "✓ kubectl configured for gitea-runner user"

# Test as gitea-runner
log_info "Testing kubectl as gitea-runner user..."
if sudo -u gitea-runner kubectl get nodes &> /dev/null; then
    log_info "✓ gitea-runner can access K3s cluster"
    sudo -u gitea-runner kubectl get nodes
else
    log_error "gitea-runner cannot access K3s cluster"
    exit 1
fi

log_info ""
log_info "=========================================="
log_info "Setup Complete!"
log_info "=========================================="
log_info "kubectl configured for:"
log_info "  - Current user: $USER"
log_info "  - gitea-runner user"
log_info ""
log_info "K3s cluster: ${K3S_HOST}:${K3S_PORT}"
log_info "Kubeconfig: $KUBECONFIG_FILE"
log_info ""
log_info "Test commands:"
log_info "  kubectl get nodes"
log_info "  kubectl get pods -A"
log_info "  sudo -u gitea-runner kubectl get nodes"
log_info "=========================================="

# Made with Bob