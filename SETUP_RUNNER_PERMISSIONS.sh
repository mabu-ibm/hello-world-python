#!/bin/bash
# Setup Gitea Runner Permissions
# This script configures the runner user with proper group memberships

set -e

echo "=========================================="
echo "Gitea Runner Permissions Setup"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect runner user
RUNNER_USER="${RUNNER_USER:-gitea-runner}"

echo -e "${YELLOW}Checking runner user: $RUNNER_USER${NC}\n"

# Check if user exists
if ! id "$RUNNER_USER" &>/dev/null; then
    echo -e "${RED}✗ User $RUNNER_USER does not exist!${NC}"
    echo ""
    echo "Common runner usernames:"
    echo "  - gitea-runner"
    echo "  - runner"
    echo "  - act_runner"
    echo "  - gitea"
    echo ""
    echo "To find the runner user:"
    echo "  ps aux | grep gitea"
    echo "  ps aux | grep runner"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ User $RUNNER_USER exists${NC}"

# Check current groups
echo -e "\n${YELLOW}Current groups for $RUNNER_USER:${NC}"
groups $RUNNER_USER

# Check if docker group exists
if ! getent group docker &>/dev/null; then
    echo -e "\n${RED}✗ Docker group does not exist!${NC}"
    echo "Creating docker group..."
    sudo groupadd docker
    echo -e "${GREEN}✓ Docker group created${NC}"
fi

# Check if user is in docker group
if groups $RUNNER_USER | grep -q '\bdocker\b'; then
    echo -e "\n${GREEN}✓ User $RUNNER_USER is already in docker group${NC}"
else
    echo -e "\n${YELLOW}Adding $RUNNER_USER to docker group...${NC}"
    sudo usermod -aG docker $RUNNER_USER
    echo -e "${GREEN}✓ User added to docker group${NC}"
fi

# Check if user is in wheel/sudo group (optional but recommended)
if groups $RUNNER_USER | grep -qE '\b(wheel|sudo)\b'; then
    echo -e "${GREEN}✓ User $RUNNER_USER is in admin group (wheel/sudo)${NC}"
else
    echo -e "${YELLOW}⚠ User $RUNNER_USER is NOT in admin group${NC}"
    echo "This is optional but recommended for troubleshooting."
    echo ""
    read -p "Add $RUNNER_USER to wheel group? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo usermod -aG wheel $RUNNER_USER
        echo -e "${GREEN}✓ User added to wheel group${NC}"
    fi
fi

# Show updated groups
echo -e "\n${YELLOW}Updated groups for $RUNNER_USER:${NC}"
groups $RUNNER_USER

# Check if runner service exists
echo -e "\n${YELLOW}Checking runner service...${NC}"
if systemctl list-units --type=service --all | grep -qE 'gitea-runner|act_runner'; then
    RUNNER_SERVICE=$(systemctl list-units --type=service --all | grep -E 'gitea-runner|act_runner' | awk '{print $1}' | head -1)
    echo -e "${GREEN}✓ Found runner service: $RUNNER_SERVICE${NC}"
    
    echo -e "\n${YELLOW}Restarting runner service to apply group changes...${NC}"
    sudo systemctl restart $RUNNER_SERVICE
    
    sleep 2
    
    if sudo systemctl is-active $RUNNER_SERVICE &>/dev/null; then
        echo -e "${GREEN}✓ Runner service restarted successfully${NC}"
    else
        echo -e "${RED}✗ Runner service failed to restart${NC}"
        sudo systemctl status $RUNNER_SERVICE
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Runner service not found${NC}"
    echo "You may need to restart the runner manually"
fi

# Test Docker access
echo -e "\n${YELLOW}Testing Docker access for $RUNNER_USER...${NC}"
if sudo -u $RUNNER_USER docker ps &>/dev/null; then
    echo -e "${GREEN}✓ User $RUNNER_USER can access Docker!${NC}"
else
    echo -e "${RED}✗ User $RUNNER_USER cannot access Docker${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Verify Docker is running:"
    echo "     sudo systemctl status docker"
    echo ""
    echo "  2. Check Docker socket permissions:"
    echo "     ls -l /var/run/docker.sock"
    echo "     Should show: srw-rw---- 1 root docker"
    echo ""
    echo "  3. Restart Docker service:"
    echo "     sudo systemctl restart docker"
    echo ""
    echo "  4. Log out and log back in (or restart runner)"
    echo ""
    exit 1
fi

# Test kubectl access
echo -e "\n${YELLOW}Testing kubectl access for $RUNNER_USER...${NC}"
if sudo -u $RUNNER_USER kubectl version --client &>/dev/null; then
    echo -e "${GREEN}✓ User $RUNNER_USER can access kubectl!${NC}"
else
    echo -e "${YELLOW}⚠ User $RUNNER_USER cannot access kubectl${NC}"
    echo "This is OK if kubeconfig will be provided via secrets"
fi

echo -e "\n${GREEN}=========================================="
echo "✓ Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Summary:"
echo "  User: $RUNNER_USER"
echo "  Groups: $(groups $RUNNER_USER | cut -d: -f2)"
echo "  Docker Access: ✓"
echo "  kubectl Access: $(sudo -u $RUNNER_USER kubectl version --client &>/dev/null && echo '✓' || echo '⚠ (will use secrets)')"
echo ""
echo "Important Notes:"
echo "  1. Group changes are now active for new sessions"
echo "  2. Runner service has been restarted"
echo "  3. Workflow should now work with native Docker/kubectl"
echo ""
echo "Next Steps:"
echo "  1. Ensure Gitea secrets are configured:"
echo "     - GIT_REGISTRY"
echo "     - GIT_USERNAME"
echo "     - GIT_TOKEN"
echo "     - KUBECONFIG"
echo ""
echo "  2. Push code to trigger workflow:"
echo "     git push origin main"
echo ""
echo "  3. Monitor workflow in Gitea Actions UI"

# Made with Bob
