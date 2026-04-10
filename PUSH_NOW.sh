#!/bin/bash
################################################################################
# Quick Push Script
# Purpose: Stash, pull, merge, and push all changes to Gitea
# Usage: ./PUSH_NOW.sh
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Pushing updates to Gitea..."
echo ""

# Step 1: Stash local changes
log_info "Step 1: Stashing local changes..."
git stash
echo ""

# Step 2: Pull remote changes
log_info "Step 2: Pulling remote changes..."
git pull origin main
echo ""

# Step 3: Apply stashed changes
log_info "Step 3: Applying stashed changes..."
git stash pop
echo ""

# Step 4: Add all files
log_info "Step 4: Adding all files..."
git add .
echo ""

# Step 5: Commit
log_info "Step 5: Committing changes..."
git commit -m "Add K8s deployment with automated CI/CD

Features:
- Kubernetes deployment manifests (2 replicas, LoadBalancer)
- Registry secret setup script
- Remote kubectl configuration script
- Full CI/CD pipeline (test → build → deploy)
- kubectl installed in deploy job with full paths
- Complete deployment guide

Architecture:
- Runner on almabuild deploys to almak3s remotely
- No runner needed on K3s host
- Automated deployment on every push

Created with IBM Bob AI"
echo ""

# Step 6: Push
log_info "Step 6: Pushing to Gitea..."
git push origin main
echo ""

log_info "=========================================="
log_info "✓ Successfully pushed to Gitea!"
log_info "=========================================="
log_info ""
log_info "Next steps:"
log_info "1. Go to Gitea: http://almabuild:3000/manfred/hello-world-python"
log_info "2. Click Actions tab"
log_info "3. Watch workflow run (test → build → deploy)"
log_info "4. Check deployment: kubectl get pods -l app=hello-world-python"
log_info "=========================================="

# Made with Bob