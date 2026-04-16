#!/bin/bash
# Setup Native Docker and kubectl in Gitea Runner Container
# This enables the native workflow to work in containerized runners

set -e

echo "=================================================="
echo "Setup Native Docker & kubectl in Gitea Runner"
echo "=================================================="
echo ""

# Check if running inside container
if [ ! -f /.dockerenv ] && [ ! -f /run/.containerenv ]; then
    echo "⚠️  WARNING: This script should be run INSIDE the Gitea runner container"
    echo ""
    echo "To run this script:"
    echo "  1. Find your runner container:"
    echo "     docker ps | grep runner"
    echo ""
    echo "  2. Copy this script to the container:"
    echo "     docker cp SETUP_NATIVE_RUNNER.sh <container-name>:/tmp/"
    echo ""
    echo "  3. Execute inside the container:"
    echo "     docker exec -it <container-name> sh /tmp/SETUP_NATIVE_RUNNER.sh"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Step 1: Detecting OS and Package Manager..."
echo "=================================================="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
    echo "✓ Detected OS: $OS $VERSION"
else
    echo "❌ Cannot detect OS"
    exit 1
fi

# Determine package manager
if command -v apk &> /dev/null; then
    PKG_MGR="apk"
    echo "✓ Package Manager: Alpine (apk)"
elif command -v apt-get &> /dev/null; then
    PKG_MGR="apt"
    echo "✓ Package Manager: Debian/Ubuntu (apt)"
elif command -v yum &> /dev/null; then
    PKG_MGR="yum"
    echo "✓ Package Manager: RHEL/CentOS (yum)"
else
    echo "❌ Unsupported package manager"
    exit 1
fi

echo ""
echo "Step 2: Installing Docker CLI..."
echo "=================================================="

if command -v docker &> /dev/null; then
    echo "✓ Docker already installed: $(docker --version)"
else
    case $PKG_MGR in
        apk)
            echo "Installing Docker CLI via apk..."
            apk add --no-cache docker-cli docker-cli-buildx
            ;;
        apt)
            echo "Installing Docker CLI via apt..."
            apt-get update
            apt-get install -y docker.io
            ;;
        yum)
            echo "Installing Docker CLI via yum..."
            yum install -y docker
            ;;
    esac
    
    if command -v docker &> /dev/null; then
        echo "✓ Docker installed: $(docker --version)"
    else
        echo "❌ Docker installation failed"
        exit 1
    fi
fi

echo ""
echo "Step 3: Verifying Docker Socket Access..."
echo "=================================================="

if [ -S /var/run/docker.sock ]; then
    echo "✓ Docker socket found: /var/run/docker.sock"
    ls -la /var/run/docker.sock
    
    # Test Docker access
    if docker ps &> /dev/null; then
        echo "✓ Docker is accessible and working"
        docker version
    else
        echo "⚠️  Docker socket exists but not accessible"
        echo ""
        echo "The runner container needs Docker socket mounted."
        echo "Add this to your runner's docker-compose.yml or run command:"
        echo ""
        echo "volumes:"
        echo "  - /var/run/docker.sock:/var/run/docker.sock"
        echo ""
        echo "Then restart the runner container."
        exit 1
    fi
else
    echo "❌ Docker socket not found at /var/run/docker.sock"
    echo ""
    echo "The runner container needs Docker socket mounted."
    echo "Add this to your runner's docker-compose.yml or run command:"
    echo ""
    echo "volumes:"
    echo "  - /var/run/docker.sock:/var/run/docker.sock"
    echo ""
    exit 1
fi

echo ""
echo "Step 4: Installing kubectl..."
echo "=================================================="

if command -v kubectl &> /dev/null; then
    echo "✓ kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    echo "Installing kubectl..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            KUBECTL_ARCH="amd64"
            ;;
        aarch64|arm64)
            KUBECTL_ARCH="arm64"
            ;;
        *)
            echo "❌ Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    echo "Architecture: $KUBECTL_ARCH"
    
    # Download kubectl
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    echo "Latest kubectl version: $KUBECTL_VERSION"
    
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl"
    
    # Install kubectl
    chmod +x kubectl
    mv kubectl /usr/local/bin/kubectl
    
    if command -v kubectl &> /dev/null; then
        echo "✓ kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    else
        echo "❌ kubectl installation failed"
        exit 1
    fi
fi

echo ""
echo "Step 5: Installing Additional Tools..."
echo "=================================================="

# Install common tools needed by workflows
case $PKG_MGR in
    apk)
        echo "Installing: git, bash, curl, openssl, python3, pip..."
        apk add --no-cache git bash curl openssl python3 py3-pip
        ;;
    apt)
        echo "Installing: git, curl, openssl, python3, pip..."
        apt-get install -y git curl openssl python3 python3-pip
        ;;
    yum)
        echo "Installing: git, curl, openssl, python3, pip..."
        yum install -y git curl openssl python3 python3-pip
        ;;
esac

echo "✓ Additional tools installed"

echo ""
echo "Step 6: Verification..."
echo "=================================================="

echo ""
echo "Docker:"
docker --version
docker info | head -n 10

echo ""
echo "kubectl:"
kubectl version --client

echo ""
echo "Python:"
python3 --version
pip3 --version

echo ""
echo "Git:"
git --version

echo ""
echo "OpenSSL:"
openssl version

echo ""
echo "=================================================="
echo "✅ SUCCESS: Native tools installed in runner"
echo "=================================================="
echo ""
echo "The native workflow (build-push-deploy-native.yaml) should now work!"
echo ""
echo "Next steps:"
echo "  1. Restart the runner container (if needed):"
echo "     docker restart <runner-container-name>"
echo ""
echo "  2. Verify the workflow runs successfully in Gitea"
echo ""
echo "  3. If issues persist, check:"
echo "     - Docker socket is mounted: /var/run/docker.sock"
echo "     - Runner has permission to access Docker socket"
echo "     - KUBECONFIG secret is properly configured"
echo ""

# Made with Bob
