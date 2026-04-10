#!/bin/bash
# Fix HTTP Registry Access on K8s Nodes
# This script configures all K8s nodes to accept HTTP registry connections

set -e

echo "=========================================="
echo "Fix HTTP Registry on K8s Nodes"
echo "=========================================="

# Configuration
REGISTRY_HOST="${REGISTRY_HOST:-almabuild2.lab.allwaysbeginner.com:3000}"
K8S_NODES="${K8S_NODES}"  # Space-separated list of nodes

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if nodes are provided
if [ -z "$K8S_NODES" ]; then
    echo -e "${YELLOW}Detecting K8s nodes...${NC}"
    K8S_NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    echo -e "${GREEN}Found nodes: $K8S_NODES${NC}"
fi

echo -e "\n${YELLOW}Registry: ${REGISTRY_HOST}${NC}"
echo -e "${YELLOW}Nodes to configure: ${K8S_NODES}${NC}\n"

# Function to configure a node
configure_node() {
    local NODE=$1
    echo -e "\n${YELLOW}=========================================="
    echo "Configuring node: $NODE"
    echo "==========================================${NC}"
    
    # Check if we can SSH to the node
    if ! ssh -o ConnectTimeout=5 $NODE "echo 'SSH OK'" &>/dev/null; then
        echo -e "${RED}✗ Cannot SSH to $NODE${NC}"
        echo "Please ensure:"
        echo "  1. SSH key is configured"
        echo "  2. Node hostname is correct"
        echo "  3. Node is reachable"
        return 1
    fi
    
    echo -e "${GREEN}✓ SSH connection OK${NC}"
    
    # Backup existing daemon.json
    echo "Backing up existing Docker config..."
    ssh $NODE "sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true"
    
    # Check if daemon.json exists
    if ssh $NODE "test -f /etc/docker/daemon.json"; then
        echo "Updating existing daemon.json..."
        
        # Read existing config and add insecure registry
        ssh $NODE "cat > /tmp/update-docker-config.sh << 'EOFSCRIPT'
#!/bin/bash
CONFIG_FILE=/etc/docker/daemon.json
REGISTRY=\"${REGISTRY_HOST}\"

# Read existing config
if [ -f \$CONFIG_FILE ]; then
    EXISTING=\$(cat \$CONFIG_FILE)
else
    EXISTING='{}'
fi

# Use Python to update JSON (more reliable than jq)
python3 << 'EOFPYTHON'
import json
import sys

config_file = '/etc/docker/daemon.json'
registry = '${REGISTRY_HOST}'

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except:
    config = {}

# Add or update insecure-registries
if 'insecure-registries' not in config:
    config['insecure-registries'] = []

if registry not in config['insecure-registries']:
    config['insecure-registries'].append(registry)

# Write back
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print('Updated daemon.json:')
print(json.dumps(config, indent=2))
EOFPYTHON
EOFSCRIPT
chmod +x /tmp/update-docker-config.sh
sudo /tmp/update-docker-config.sh
"
    else
        echo "Creating new daemon.json..."
        ssh $NODE "sudo mkdir -p /etc/docker && echo '{
  \"insecure-registries\": [\"${REGISTRY_HOST}\"]
}' | sudo tee /etc/docker/daemon.json"
    fi
    
    # Show the config
    echo -e "\n${YELLOW}Current daemon.json:${NC}"
    ssh $NODE "sudo cat /etc/docker/daemon.json"
    
    # Restart Docker
    echo -e "\n${YELLOW}Restarting Docker...${NC}"
    ssh $NODE "sudo systemctl restart docker"
    
    # Wait for Docker to be ready
    sleep 3
    
    # Verify Docker is running
    if ssh $NODE "sudo systemctl is-active docker" | grep -q "active"; then
        echo -e "${GREEN}✓ Docker restarted successfully${NC}"
    else
        echo -e "${RED}✗ Docker failed to restart${NC}"
        ssh $NODE "sudo systemctl status docker"
        return 1
    fi
    
    # Test registry access
    echo -e "\n${YELLOW}Testing registry access...${NC}"
    if ssh $NODE "curl -s http://${REGISTRY_HOST}/v2/" &>/dev/null; then
        echo -e "${GREEN}✓ Registry is accessible from node${NC}"
    else
        echo -e "${YELLOW}⚠ Registry endpoint test inconclusive (may require auth)${NC}"
    fi
    
    echo -e "${GREEN}✓ Node $NODE configured successfully${NC}"
}

# Configure all nodes
FAILED_NODES=""
for NODE in $K8S_NODES; do
    if ! configure_node $NODE; then
        FAILED_NODES="$FAILED_NODES $NODE"
    fi
done

echo -e "\n${GREEN}=========================================="
echo "Configuration Complete"
echo "==========================================${NC}"

if [ -n "$FAILED_NODES" ]; then
    echo -e "${RED}Failed nodes:$FAILED_NODES${NC}"
    echo "Please configure these nodes manually"
    exit 1
fi

echo -e "${GREEN}✓ All nodes configured successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. Delete existing pods to force re-pull:"
echo "     kubectl delete pods -l app=hello-world-python -n default"
echo ""
echo "  2. Watch pods come back up:"
echo "     kubectl get pods -n default -w"
echo ""
echo "  3. If still failing, check pod events:"
echo "     kubectl describe pod <pod-name> -n default"

# Made with Bob
