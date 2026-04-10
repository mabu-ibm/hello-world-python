#!/bin/bash

# Fix Firewall to Allow NodePort 30080
# Run this on your K3s machine (almak3s)

set -e

echo "=========================================="
echo "Opening Firewall Port 30080 for K3s NodePort"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo:"
    echo "  sudo ./fix-firewall.sh"
    exit 1
fi

# Detect firewall type
if command -v firewall-cmd &> /dev/null; then
    echo "✅ Detected: firewalld (AlmaLinux/RHEL/CentOS)"
    echo ""
    
    echo "Current firewall ports:"
    firewall-cmd --list-ports
    echo ""
    
    echo "Adding port 30080/tcp..."
    firewall-cmd --add-port=30080/tcp --permanent
    
    echo "Reloading firewall..."
    firewall-cmd --reload
    
    echo ""
    echo "✅ Port 30080 opened successfully!"
    echo ""
    echo "Verify with:"
    firewall-cmd --list-ports
    
elif command -v ufw &> /dev/null; then
    echo "✅ Detected: UFW (Ubuntu/Debian)"
    echo ""
    
    echo "Current firewall status:"
    ufw status
    echo ""
    
    echo "Adding port 30080/tcp..."
    ufw allow 30080/tcp
    
    echo ""
    echo "✅ Port 30080 opened successfully!"
    echo ""
    echo "Verify with:"
    ufw status
    
else
    echo "⚠️  No firewall detected (firewalld or ufw)"
    echo ""
    echo "Checking iptables..."
    
    if iptables -L -n | grep -q "30080"; then
        echo "✅ Port 30080 already in iptables"
    else
        echo "Adding iptables rule..."
        iptables -A INPUT -p tcp --dport 30080 -j ACCEPT
        
        # Try to save (method varies by distro)
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
            iptables-save > /etc/sysconfig/iptables 2>/dev/null || \
            echo "⚠️  Could not persist iptables rules automatically"
        fi
        
        echo "✅ iptables rule added"
    fi
fi

echo ""
echo "=========================================="
echo "Testing Access"
echo "=========================================="
echo ""

# Get node IP
NODE_IP=$(hostname -I | awk '{print $1}')
echo "Node IP: $NODE_IP"
echo ""

echo "Testing local access..."
if curl -s -f http://localhost:30080 > /dev/null 2>&1; then
    echo "✅ Local access works"
else
    echo "❌ Local access failed - check if app is running"
    exit 1
fi

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "Test from your MacBook:"
echo "  curl http://almak3s.lab.allwaysbeginner.com:30080"
echo ""
echo "Or open in browser:"
echo "  http://almak3s.lab.allwaysbeginner.com:30080"
echo ""
echo "If still not working, check:"
echo "  1. DNS resolves correctly: ping almak3s.lab.allwaysbeginner.com"
echo "  2. Network route exists: traceroute almak3s.lab.allwaysbeginner.com"
echo "  3. No intermediate firewall blocking traffic"
echo ""

# Made with Bob
