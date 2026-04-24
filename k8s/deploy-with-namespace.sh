#!/bin/bash

# Deploy hello-world-python application with dedicated namespace
# This script creates the namespace and deploys all resources into it

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="hello-world-python"
DEPLOYMENT_TYPE="${1:-standard}"  # standard, secure, or flexible

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Hello World Python - Namespace Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check cluster connectivity
print_info "Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Connected to cluster"

# Create namespace
print_info "Creating namespace: ${NAMESPACE}"
if kubectl get namespace ${NAMESPACE} &> /dev/null; then
    print_warning "Namespace ${NAMESPACE} already exists"
else
    kubectl apply -f k8s/namespace.yaml
    print_success "Namespace created"
fi

# Create registry secret in the namespace if it doesn't exist
print_info "Checking for registry secret..."
if ! kubectl get secret gitea-registry -n ${NAMESPACE} &> /dev/null; then
    print_warning "Registry secret 'gitea-registry' not found in namespace ${NAMESPACE}"
    print_info "You may need to create it manually with:"
    echo "  kubectl create secret docker-registry gitea-registry \\"
    echo "    --docker-server=<registry-url> \\"
    echo "    --docker-username=<username> \\"
    echo "    --docker-password=<password> \\"
    echo "    --namespace=${NAMESPACE}"
else
    print_success "Registry secret found"
fi

# Deploy based on type
case ${DEPLOYMENT_TYPE} in
    standard)
        print_info "Deploying standard configuration..."
        
        # Set default values if not provided
        export IMAGE_REGISTRY="${IMAGE_REGISTRY:-almabuild.lab.allwaysbeginner.com:3000}"
        export IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-manfred/hello-world-python}"
        export IMAGE_TAG="${IMAGE_TAG:-latest}"
        export INGRESS_HOST="${INGRESS_HOST:-hello.lab.allwaysbeginner.com}"
        
        print_info "Using configuration:"
        echo "  Registry: ${IMAGE_REGISTRY}"
        echo "  Repository: ${IMAGE_REPOSITORY}"
        echo "  Tag: ${IMAGE_TAG}"
        echo "  Ingress Host: ${INGRESS_HOST}"
        
        # Apply deployment with variable substitution
        envsubst < k8s/deployment.yaml | kubectl apply -f -
        envsubst < k8s/ingress.yaml | kubectl apply -f -
        ;;
        
    secure)
        print_info "Deploying secure configuration..."
        kubectl apply -f k8s/deployment-secure.yaml
        
        export INGRESS_HOST="${INGRESS_HOST:-hello.lab.allwaysbeginner.com}"
        envsubst < k8s/ingress-secure.yaml | kubectl apply -f -
        ;;
        
    flexible)
        print_info "Deploying flexible configuration..."
        
        export IMAGE_REGISTRY="${IMAGE_REGISTRY:-almabuild.lab.allwaysbeginner.com:3000}"
        export IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-manfred/hello-world-python}"
        export IMAGE_TAG="${IMAGE_TAG:-latest}"
        export INGRESS_HOST="${INGRESS_HOST:-hello.lab.allwaysbeginner.com}"
        
        envsubst < k8s/deployment.yaml | kubectl apply -f -
        envsubst < k8s/ingress-flexible.yaml | kubectl apply -f -
        ;;
        
    *)
        print_error "Invalid deployment type: ${DEPLOYMENT_TYPE}"
        echo "Usage: $0 [standard|secure|flexible]"
        exit 1
        ;;
esac

print_success "Deployment applied"

# Wait for deployment to be ready
print_info "Waiting for deployment to be ready..."
if kubectl wait --for=condition=available --timeout=300s \
    deployment/hello-world-python -n ${NAMESPACE} 2>/dev/null; then
    print_success "Deployment is ready"
else
    print_warning "Deployment is taking longer than expected"
fi

# Show deployment status
echo ""
print_info "Deployment Status:"
kubectl get all -n ${NAMESPACE}

echo ""
print_info "Ingress Status:"
kubectl get ingress -n ${NAMESPACE}

# Show access information
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Namespace: ${NAMESPACE}"
echo "Access URLs:"
echo "  - Internal: http://hello-world-python.${NAMESPACE}.svc.cluster.local"
if [ ! -z "${INGRESS_HOST}" ]; then
    echo "  - External: http://${INGRESS_HOST}"
    echo "  - External (HTTPS): https://${INGRESS_HOST}"
fi
echo ""
echo "Useful commands:"
echo "  kubectl get all -n ${NAMESPACE}"
echo "  kubectl logs -n ${NAMESPACE} -l app=hello-world-python"
echo "  kubectl describe pod -n ${NAMESPACE} -l app=hello-world-python"
echo "  kubectl delete namespace ${NAMESPACE}  # To remove everything"
echo ""

# Made with Bob