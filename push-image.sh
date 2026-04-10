#!/bin/bash
################################################################################
# Push Docker Image to Gitea Registry
# Purpose: Manually push built image to Gitea registry
# Usage: ./push-image.sh
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

# Configuration
GITEA_REGISTRY="almabuild:3000"
IMAGE_NAME="hello-world-python"

log_info "Push Docker Image to Gitea Registry"
echo ""

# Get username
read -p "Enter your Gitea username: " GITEA_USER

# Full image name
FULL_IMAGE="${GITEA_REGISTRY}/${GITEA_USER}/${IMAGE_NAME}"

# Check if image exists locally
if ! docker images | grep -q "${IMAGE_NAME}"; then
    log_warn "Image not found locally. Building..."
    docker build -t ${IMAGE_NAME}:latest .
fi

# Tag image
log_info "Tagging image..."
docker tag ${IMAGE_NAME}:latest ${FULL_IMAGE}:latest

# Get commit SHA if in git repo
if git rev-parse --git-dir > /dev/null 2>&1; then
    COMMIT_SHA=$(git rev-parse --short HEAD)
    docker tag ${IMAGE_NAME}:latest ${FULL_IMAGE}:${COMMIT_SHA}
    log_info "Tagged with commit SHA: ${COMMIT_SHA}"
fi

# Login to registry
log_info "Logging into Gitea registry..."
docker login ${GITEA_REGISTRY}

# Push images
log_info "Pushing images..."
docker push ${FULL_IMAGE}:latest

if [ -n "${COMMIT_SHA:-}" ]; then
    docker push ${FULL_IMAGE}:${COMMIT_SHA}
fi

log_info "============================================"
log_info "Successfully pushed to Gitea registry!"
log_info "============================================"
log_info "Images:"
log_info "  - ${FULL_IMAGE}:latest"
if [ -n "${COMMIT_SHA:-}" ]; then
    log_info "  - ${FULL_IMAGE}:${COMMIT_SHA}"
fi
log_info ""
log_info "Pull command:"
log_info "  docker pull ${FULL_IMAGE}:latest"
log_info "============================================"

# Made with Bob
