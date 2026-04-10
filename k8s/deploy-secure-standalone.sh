#!/bin/bash

# Standalone Secure Deployment Script
# This script can be run directly on almak3s without cloning the repo
# It creates all necessary manifests inline and deploys them

set -e

echo "=========================================="
echo "Standalone Secure Deployment"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found${NC}"
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    sudo ln -sf /usr/local/bin/kubectl /usr/bin/kubectl
fi

# Setup kubeconfig if needed
if [ ! -f ~/.kube/config ] && [ -f /etc/rancher/k3s/k3s.yaml ]; then
    echo "Setting up kubeconfig..."
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    chmod 600 ~/.kube/config
fi

# Get configuration
read -p "Enter your Gitea username: " GITEA_USER
read -p "Enter image name (default: hello-world-python): " IMAGE_NAME
IMAGE_NAME=${IMAGE_NAME:-hello-world-python}

REGISTRY="almabuild.lab.allwaysbeginner.com:3000"
IMAGE="${REGISTRY}/${GITEA_USER}/${IMAGE_NAME}:latest"

echo ""
echo "Configuration:"
echo "  Registry: $REGISTRY"
echo "  Image: $IMAGE"
echo ""

# Create temporary directory for manifests
TEMP_DIR=$(mktemp -d)
echo "Creating manifests in $TEMP_DIR..."

# Create deployment-secure.yaml
cat > "$TEMP_DIR/deployment-secure.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-python
  namespace: default
  labels:
    app: hello-world-python
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-world-python
  template:
    metadata:
      labels:
        app: hello-world-python
        version: v1
    spec:
      serviceAccountName: hello-world-python
      automountServiceAccountToken: false
      imagePullSecrets:
      - name: gitea-registry
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: hello-world-python
        image: ${IMAGE}
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
          seccompProfile:
            type: RuntimeDefault
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 0
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 30
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
            ephemeral-storage: "100Mi"
          limits:
            memory: "256Mi"
            cpu: "200m"
            ephemeral-storage: "200Mi"
        envFrom:
        - configMapRef:
            name: hello-world-python-config
        - secretRef:
            name: hello-world-python-secrets
            optional: true
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /home/appuser/.cache
      volumes:
      - name: tmp
        emptyDir:
          sizeLimit: 100Mi
      - name: cache
        emptyDir:
          sizeLimit: 100Mi
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - hello-world-python
              topologyKey: kubernetes.io/hostname
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hello-world-python
  namespace: default
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: hello-world-python-config
  namespace: default
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
---
apiVersion: v1
kind: Secret
metadata:
  name: hello-world-python-secrets
  namespace: default
type: Opaque
stringData:
  PLACEHOLDER: "replace-with-actual-secrets"
---
apiVersion: v1
kind: Service
metadata:
  name: hello-world-python
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: hello-world-python
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
EOF

# Create network-policy.yaml
cat > "$TEMP_DIR/network-policy.yaml" <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: hello-world-python-netpol
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: hello-world-python
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: TCP
      port: 8080
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
EOF

echo -e "${GREEN}✓ Manifests created${NC}"

# Check for existing deployment
if kubectl get deployment hello-world-python &> /dev/null; then
    echo -e "${YELLOW}Warning: Existing deployment found${NC}"
    read -p "Replace with secure deployment? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete deployment hello-world-python
        kubectl delete service hello-world-python
        echo -e "${GREEN}✓ Old deployment removed${NC}"
    else
        echo "Exiting..."
        rm -rf "$TEMP_DIR"
        exit 0
    fi
fi

# Apply manifests
echo ""
echo "Deploying secure application..."
kubectl apply -f "$TEMP_DIR/deployment-secure.yaml"
kubectl apply -f "$TEMP_DIR/network-policy.yaml"

echo ""
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=hello-world-python --timeout=120s || true

# Verify
echo ""
echo "=========================================="
echo "Verification"
echo "=========================================="

POD=$(kubectl get pod -l app=hello-world-python -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$POD" ]; then
    echo ""
    echo "Security Checks:"
    
    echo -n "  - Non-root user: "
    USER_ID=$(kubectl exec $POD -- id -u 2>/dev/null || echo "")
    if [ "$USER_ID" == "1000" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    
    echo -n "  - Read-only filesystem: "
    if kubectl exec $POD -- touch /test 2>&1 | grep -q "Read-only file system"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    
    echo -n "  - Health check: "
    if kubectl exec $POD -- curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
fi

echo ""
echo "Deployment Status:"
kubectl get pods -l app=hello-world-python
echo ""
kubectl get service hello-world-python

# Get service IP
SERVICE_IP=$(kubectl get service hello-world-python -o jsonpath='{.spec.clusterIP}')

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Access your application:"
echo "  ClusterIP: http://$SERVICE_IP/"
echo ""
echo "Port-forward for external access:"
echo "  kubectl port-forward service/hello-world-python 8080:80"
echo "  curl http://localhost:8080/"
echo ""
echo "View logs:"
echo "  kubectl logs -l app=hello-world-python -f"
echo ""
echo "Security features enabled:"
echo "  ✓ Non-root user (UID 1000)"
echo "  ✓ Read-only root filesystem"
echo "  ✓ Dropped all capabilities"
echo "  ✓ Network policies"
echo "  ✓ Resource limits"
echo "  ✓ Security contexts"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"
echo -e "${GREEN}Secure deployment complete!${NC}"

# Made with Bob
