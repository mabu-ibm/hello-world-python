#!/bin/bash
# Fix HTTP Registry Access on K3s Nodes
# K3s uses /etc/rancher/k3s/registries.yaml instead of Docker daemon.json

set -e

echo "=========================================="
echo "Fix HTTP Registry on K3s Nodes"
echo "=========================================="

# Configuration
REGISTRY_HOST="${REGISTRY_HOST:-almabuild2.lab.allwaysbeginner.com:3000}"
K3S_NODES="${K3S_NODES}"  # Space-separated list of nodes

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if nodes are provided
if [ -z "$K3S_NODES" ]; then
    echo -e "${YELLOW}Detecting K3s nodes...${NC}"
    K3S_NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    echo -e "${GREEN}Found nodes: $K3S_NODES${NC}"
fi

echo -e "\n${YELLOW}Registry: ${REGISTRY_HOST}${NC}"
echo -e "${YELLOW}Nodes to configure: ${K3S_NODES}${NC}\n"

# Function to configure a K3s node
configure_k3s_node() {
    local NODE=$1
    echo -e "\n${YELLOW}=========================================="
    echo "Configuring K3s node: $NODE"
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
    
    # Create K3s config directory if it doesn't exist
    echo "Creating K3s config directory..."
    ssh $NODE "sudo mkdir -p /etc/rancher/k3s"
    
    # Backup existing registries.yaml
    echo "Backing up existing registries.yaml..."
    ssh $NODE "sudo cp /etc/rancher/k3s/registries.yaml /etc/rancher/k3s/registries.yaml.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true"
    
    # Create registries.yaml
    echo "Creating registries.yaml..."
    ssh $NODE "sudo tee /etc/rancher/k3s/registries.yaml > /dev/null << 'EOFREGISTRY'
mirrors:
  \"${REGISTRY_HOST}\":
    endpoint:
      - \"http://${REGISTRY_HOST}\"

configs:
  \"${REGISTRY_HOST}\":
    tls:
      insecure_skip_verify: true
EOFREGISTRY
"
    
    # Show the config
    echo -e "\n${YELLOW}Current registries.yaml:${NC}"
    ssh $NODE "sudo cat /etc/rancher/k3s/registries.yaml"
    
    # Restart K3s
    echo -e "\n${YELLOW}Restarting K3s...${NC}"
    ssh $NODE "sudo systemctl restart k3s"
    
    # Wait for K3s to be ready
    echo "Waiting for K3s to be ready..."
    sleep 10
    
    # Verify K3s is running
    if ssh $NODE "sudo systemctl is-active k3s" | grep -q "active"; then
        echo -e "${GREEN}✓ K3s restarted successfully${NC}"
    else
        echo -e "${RED}✗ K3s failed to restart${NC}"
        ssh $NODE "sudo systemctl status k3s"
        return 1
    fi
    
    # Test registry access
    echo -e "\n${YELLOW}Testing registry access...${NC}"
    if ssh $NODE "curl -s http://${REGISTRY_HOST}/v2/" &>/dev/null; then
        echo -e "${GREEN}✓ Registry is accessible from node${NC}"
    else
        echo -e "${YELLOW}⚠ Registry endpoint test inconclusive (may require auth)${NC}"
    fi
    
    # Test with crictl (K3s container runtime)
    echo -e "\n${YELLOW}Testing image pull with crictl...${NC}"
    if ssh $NODE "sudo crictl pull ${REGISTRY_HOST}/manfred/hello-world-python:latest" 2>&1 | grep -q "Image is up to date\|Pull complete"; then
        echo -e "${GREEN}✓ Image pull test successful${NC}"
    else
        echo -e "${YELLOW}⚠ Image pull test failed (may need credentials)${NC}"
    fi
    
    echo -e "${GREEN}✓ Node $NODE configured successfully${NC}"
}

# Configure all nodes
FAILED_NODES=""
for NODE in $K3S_NODES; do
    if ! configure_k3s_node $NODE; then
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

echo -e "${GREEN}✓ All K3s nodes configured successfully!${NC}"
echo ""
echo "Configuration applied:"
echo "  - Registry: ${REGISTRY_HOST}"
echo "  - Protocol: HTTP (insecure_skip_verify: true)"
echo "  - Config file: /etc/rancher/k3s/registries.yaml"
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
echo ""
echo "  4. Check K3s logs on node:"
echo "     ssh <node> 'sudo journalctl -u k3s -n 50 -f'"

# Made with Bob
