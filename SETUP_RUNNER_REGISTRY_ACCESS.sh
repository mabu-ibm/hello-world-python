#!/bin/bash
################################################################################
# Setup Gitea Runner Registry Access
# Purpose: Configure runner to push to Gitea registry without authentication
# Usage: sudo ./SETUP_RUNNER_REGISTRY_ACCESS.sh
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Setup Gitea Runner Registry Access"
echo ""

# Step 1: Verify runner user exists
log_step "Step 1: Verifying gitea-runner user..."
if ! id -u gitea-runner > /dev/null 2>&1; then
    log_error "gitea-runner user does not exist"
    log_info "Please run: sudo ./vm-setup/setup-gitea-actions-runner.sh first"
    exit 1
fi
log_info "✓ gitea-runner user exists"

# Step 2: Verify runner is in docker group
log_step "Step 2: Verifying docker group membership..."
if groups gitea-runner | grep -q docker; then
    log_info "✓ gitea-runner is in docker group"
else
    log_warn "Adding gitea-runner to docker group..."
    usermod -aG docker gitea-runner
    log_info "✓ Added to docker group"
fi

# Step 3: Configure Docker for insecure registry (if needed)
log_step "Step 3: Configuring Docker daemon..."
DOCKER_DAEMON_FILE="/etc/docker/daemon.json"

if [ -f "$DOCKER_DAEMON_FILE" ]; then
    # Backup existing config
    cp "$DOCKER_DAEMON_FILE" "${DOCKER_DAEMON_FILE}.backup"
    log_info "Backed up existing Docker daemon config"
fi

# Create or update daemon.json
cat > "$DOCKER_DAEMON_FILE" <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"],
  "insecure-registries": ["almabuild:3000"]
}
EOF

log_info "✓ Docker daemon configured"

# Step 4: Restart Docker
log_step "Step 4: Restarting Docker..."
systemctl restart docker
sleep 3

if systemctl is-active --quiet docker; then
    log_info "✓ Docker restarted successfully"
else
    log_error "Docker failed to restart"
    exit 1
fi

# Step 5: Test Docker access as runner user
log_step "Step 5: Testing Docker access..."
if sudo -u gitea-runner docker ps > /dev/null 2>&1; then
    log_info "✓ gitea-runner can access Docker"
else
    log_error "gitea-runner cannot access Docker"
    log_info "You may need to log out and back in, or restart the runner service"
fi

# Step 6: Enable Gitea packages (registry)
log_step "Step 6: Verifying Gitea packages are enabled..."
GITEA_CONFIG="/var/lib/gitea/custom/conf/app.ini"

if grep -q "^\[packages\]" "$GITEA_CONFIG"; then
    if grep -A 1 "^\[packages\]" "$GITEA_CONFIG" | grep -q "ENABLED = true"; then
        log_info "✓ Gitea packages already enabled"
    else
        log_warn "Enabling Gitea packages..."
        sed -i '/^\[packages\]/,/^ENABLED/ s/ENABLED = false/ENABLED = true/' "$GITEA_CONFIG"
        systemctl restart gitea
        log_info "✓ Gitea packages enabled"
    fi
else
    log_warn "Adding packages configuration..."
    echo "" >> "$GITEA_CONFIG"
    echo "[packages]" >> "$GITEA_CONFIG"
    echo "ENABLED = true" >> "$GITEA_CONFIG"
    systemctl restart gitea
    log_info "✓ Gitea packages enabled"
fi

# Step 7: Restart runner service
log_step "Step 7: Restarting Gitea runner..."
systemctl restart gitea-runner
sleep 3

if systemctl is-active --quiet gitea-runner; then
    log_info "✓ Gitea runner restarted successfully"
else
    log_error "Gitea runner failed to restart"
    journalctl -u gitea-runner -n 20 --no-pager
    exit 1
fi

# Step 8: Test registry push
log_step "Step 8: Testing registry push..."
echo ""
log_info "Testing Docker registry push as gitea-runner user..."
echo ""

# Create test script
cat > /tmp/test-registry.sh <<'TESTEOF'
#!/bin/bash
# Pull a small test image
docker pull busybox:latest

# Tag for Gitea registry
docker tag busybox:latest almabuild:3000/test/busybox:test

# Try to push (this will fail if registry auth is required)
if docker push almabuild:3000/test/busybox:test 2>&1 | grep -q "unauthorized"; then
    echo "Registry requires authentication"
    exit 1
else
    echo "Registry push successful or registry is open"
    # Clean up
    docker rmi almabuild:3000/test/busybox:test 2>/dev/null || true
    exit 0
fi
TESTEOF

chmod +x /tmp/test-registry.sh

if sudo -u gitea-runner /tmp/test-registry.sh; then
    log_info "✓ Registry push test successful"
else
    log_warn "Registry requires authentication"
    log_info "You'll need to configure registry credentials"
fi

rm /tmp/test-registry.sh

# Summary
echo ""
log_info "============================================"
log_info "Setup Complete!"
log_info "============================================"
log_info "Configuration:"
log_info "  - gitea-runner user in docker group"
log_info "  - Docker configured for insecure registry"
log_info "  - Gitea packages enabled"
log_info "  - Runner service restarted"
echo ""
log_info "Next Steps:"
log_info "1. Push your code to Gitea"
log_info "2. Workflow will automatically build and push images"
log_info "3. Check Actions tab in repository"
echo ""
log_info "If push fails with auth error:"
log_info "1. Create Gitea access token"
log_info "2. Login as runner: sudo -u gitea-runner docker login almabuild:3000"
log_info "3. Credentials will be saved for future pushes"
log_info "============================================"

# Made with Bob
