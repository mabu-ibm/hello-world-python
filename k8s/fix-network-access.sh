#!/bin/bash

# Fix Network Access for K3s NodePort 30080
# Run this on your K3s machine (almak3s)

set -e

echo "=========================================="
echo "K3s NodePort 30080 - Network Access Fix"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo:"
    echo "  sudo ./fix-network-access.sh"
    exit 1
fi

echo "1️⃣  Checking Firewall Status..."
echo "-------------------------------------------"
if systemctl is-active --quiet firewalld; then
    echo "✅ FirewallD is running"
    echo "Opening port 30080..."
    firewall-cmd --add-port=30080/tcp --permanent
    firewall-cmd --reload
    echo "✅ Port opened in firewalld"
else
    echo "ℹ️  FirewallD is not running (this is OK)"
fi
echo ""

echo "2️⃣  Checking iptables Rules..."
echo "-------------------------------------------"
echo "Current INPUT rules for port 30080:"
iptables -L INPUT -n -v | grep 30080 || echo "No specific rule found"
echo ""

echo "Checking if K3s created iptables rules..."
iptables -L -n -t nat | grep 30080 || echo "No NAT rules found"
echo ""

echo "3️⃣  Checking Network Interfaces..."
echo "-------------------------------------------"
ip addr show
echo ""

echo "4️⃣  Checking if Port 30080 is Listening..."
echo "-------------------------------------------"
netstat -tulpn | grep 30080 || ss -tulpn | grep 30080 || echo "Port not listening!"
echo ""

echo "5️⃣  Testing Local Access..."
echo "-------------------------------------------"
if curl -s -f http://localhost:30080 > /dev/null 2>&1; then
    echo "✅ Local access works (http://localhost:30080)"
else
    echo "❌ Local access failed"
    echo ""
    echo "Checking K3s service..."
    kubectl get service hello-world-python -n default
    echo ""
    echo "Checking pods..."
    kubectl get pods -l app=hello-world-python -n default
    exit 1
fi
echo ""

echo "6️⃣  Testing Access via Node IP..."
echo "-------------------------------------------"
NODE_IP=$(hostname -I | awk '{print $1}')
echo "Node IP: $NODE_IP"
echo "Testing http://$NODE_IP:30080 ..."

if curl -s -f http://$NODE_IP:30080 > /dev/null 2>&1; then
    echo "✅ Access via node IP works"
else
    echo "❌ Access via node IP failed"
    echo ""
    echo "This suggests a network binding issue..."
fi
echo ""

echo "7️⃣  Checking K3s Configuration..."
echo "-------------------------------------------"
echo "K3s service status:"
systemctl status k3s --no-pager | head -n 10
echo ""

echo "Checking K3s network configuration..."
if [ -f /etc/systemd/system/k3s.service ]; then
    echo "K3s service file exists"
    grep -i "bind" /etc/systemd/system/k3s.service || echo "No bind configuration found"
fi
echo ""

echo "8️⃣  Checking SELinux (if applicable)..."
echo "-------------------------------------------"
if command -v getenforce &> /dev/null; then
    SELINUX_STATUS=$(getenforce)
    echo "SELinux status: $SELINUX_STATUS"
    
    if [ "$SELINUX_STATUS" = "Enforcing" ]; then
        echo "⚠️  SELinux is enforcing - this might block connections"
        echo ""
        echo "To temporarily disable (for testing):"
        echo "  sudo setenforce 0"
        echo ""
        echo "To permanently disable, edit /etc/selinux/config"
    fi
else
    echo "SELinux not installed"
fi
echo ""

echo "9️⃣  Applying Network Fixes..."
echo "-------------------------------------------"

# Ensure iptables allows the connection
echo "Adding iptables rule to allow port 30080..."
iptables -C INPUT -p tcp --dport 30080 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport 30080 -j ACCEPT

echo "✅ iptables rule added"
echo ""

# Save iptables rules
echo "Saving iptables rules..."
if command -v iptables-save &> /dev/null; then
    iptables-save > /etc/sysconfig/iptables 2>/dev/null || \
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
    echo "⚠️  Could not save iptables rules (may not persist after reboot)"
fi
echo ""

# Restart K3s to ensure proper network binding
echo "Restarting K3s service..."
systemctl restart k3s
echo "Waiting for K3s to be ready..."
sleep 10

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=hello-world-python -n default --timeout=60s 2>/dev/null || \
    echo "⚠️  Pods may not be ready yet"
echo ""

echo "🔟  Final Verification..."
echo "-------------------------------------------"
echo "Testing local access again..."
sleep 5

if curl -s -f http://localhost:30080 > /dev/null 2>&1; then
    echo "✅ Local access works!"
    
    echo ""
    echo "Testing via node IP..."
    if curl -s -f http://$NODE_IP:30080 > /dev/null 2>&1; then
        echo "✅ Node IP access works!"
    else
        echo "⚠️  Node IP access still failing"
    fi
else
    echo "❌ Local access still failing"
    echo ""
    echo "Check pod logs:"
    kubectl logs -l app=hello-world-python -n default --tail=20
fi
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "Node IP: $NODE_IP"
echo "NodePort: 30080"
echo ""
echo "Access URLs:"
echo "  Local:    http://localhost:30080"
echo "  Node IP:  http://$NODE_IP:30080"
echo "  Hostname: http://almak3s.lab.allwaysbeginner.com:30080"
echo ""
echo "Test from your MacBook:"
echo "  curl http://almak3s.lab.allwaysbeginner.com:30080"
echo ""
echo "If still not working, check:"
echo "  1. DNS resolution: ping almak3s.lab.allwaysbeginner.com"
echo "  2. Network route: traceroute almak3s.lab.allwaysbeginner.com"
echo "  3. SELinux: getenforce (should be Permissive or Disabled)"
echo "  4. Router/network firewall between MacBook and almak3s"
echo ""
echo "=========================================="

# Made with Bob
