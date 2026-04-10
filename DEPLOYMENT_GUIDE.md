# Kubernetes Deployment Guide

Complete guide for deploying the Hello World Python application to K3s with automated CI/CD.

## 🎯 Overview

This setup provides:
- ✅ Kubernetes Deployment with 2 replicas
- ✅ LoadBalancer Service for external access
- ✅ Health checks (liveness and readiness probes)
- ✅ Automated deployment via Gitea Actions
- ✅ Image pull from Gitea registry

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        almabuild                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    Gitea     │  │    Docker    │  │ Gitea Runner │      │
│  │   + Registry │  │              │  │   + kubectl  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │              │
│         │                  │                  │              │
│         └──────────────────┴──────────────────┘              │
│                            │                                 │
│                            │ Remote kubectl                  │
│                            ▼                                 │
└────────────────────────────┼─────────────────────────────────┘
                             │
                             │ Network (6443)
                             │
┌────────────────────────────▼─────────────────────────────────┐
│                        almak3s                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    K3s Cluster                        │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │   │
│  │  │   Pod 1    │  │   Pod 2    │  │  Service   │     │   │
│  │  │ hello-app  │  │ hello-app  │  │ LoadBalancer│    │   │
│  │  └────────────┘  └────────────┘  └────────────┘     │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

**Key Points:**
- ✅ **Gitea Runner runs on almabuild** (NOT on almak3s)
- ✅ **Runner uses kubectl to deploy remotely** to almak3s
- ✅ **No runner needed on almak3s** - it's just a K3s cluster
- ✅ **Network connectivity** required between almabuild and almak3s (port 6443)

## 📋 Prerequisites

### On K3s Host (almak3s)

1. **K3s installed and running**
   ```bash
   sudo systemctl status k3s
   kubectl get nodes
   ```

2. **API server accessible from almabuild**
   ```bash
   # On almabuild, test connectivity
   curl -k https://almak3s.lab.allwaysbeginner.com:6443
   ```

3. **Firewall allows port 6443**
   ```bash
   # On almak3s
   sudo firewall-cmd --list-ports
   # Should show: 6443/tcp
   
   # If not, add it:
   sudo firewall-cmd --permanent --add-port=6443/tcp
   sudo firewall-cmd --reload
   ```

### On Build Host (almabuild)

1. **Gitea Actions runner configured and running**
   ```bash
   sudo systemctl status gitea-runner
   ```

2. **kubectl installed and configured**
   ```bash
   kubectl version --client
   kubectl get nodes  # Should show almak3s node
   ```

3. **gitea-runner user has kubectl access**
   ```bash
   sudo -u gitea-runner kubectl get nodes
   ```

## 🔧 One-Time Setup

### Setup 1: Configure kubectl on almabuild

The Gitea runner on almabuild needs kubectl access to deploy to almak3s.

**Option A: Automated Script (Recommended)**

On almabuild host:

```bash
cd project-templates/hello-world-python/k8s
chmod +x setup-remote-kubectl.sh
./setup-remote-kubectl.sh
```

Follow the prompts to:
1. Install kubectl
2. Copy kubeconfig from almak3s
3. Update server address
4. Configure for gitea-runner user

**Option B: Manual Setup**

```bash
# 1. Install kubectl on almabuild
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# 2. Get kubeconfig from almak3s
# On almak3s:
sudo cat /etc/rancher/k3s/k3s.yaml

# 3. On almabuild, create kubeconfig
mkdir -p ~/.kube
nano ~/.kube/config
# Paste the content and change server: https://127.0.0.1:6443
# to: server: https://almak3s.lab.allwaysbeginner.com:6443

# 4. Test connection
kubectl get nodes

# 5. Setup for gitea-runner
sudo mkdir -p /var/lib/gitea-runner/.kube
sudo cp ~/.kube/config /var/lib/gitea-runner/.kube/config
sudo chown -R gitea-runner:gitea-runner /var/lib/gitea-runner/.kube
sudo chmod 600 /var/lib/gitea-runner/.kube/config

# 6. Test as gitea-runner
sudo -u gitea-runner kubectl get nodes
```

**Verify:**
```bash
# As your user
kubectl get nodes
# Should show almak3s node

# As gitea-runner
sudo -u gitea-runner kubectl get nodes
# Should also show almak3s node
```

### Setup 2: Open Firewall on almak3s

Ensure K3s API server is accessible:

```bash
# On almak3s
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-ports
```

Test from almabuild:
```bash
curl -k https://almak3s.lab.allwaysbeginner.com:6443
# Should return: 403 Forbidden (this is OK - means API is accessible)
```

## 🚀 Quick Start - Manual Deployment

### Step 1: Setup Registry Secret (on almak3s)

On the K3s host:

```bash
cd project-templates/hello-world-python/k8s
chmod +x setup-registry-secret.sh
./setup-registry-secret.sh
```

**Enter when prompted:**
- Gitea username: `manfred`
- Gitea password: Your Gitea password or token

**Verify:**
```bash
kubectl get secret gitea-registry -n default
```

### Step 2: Deploy Application

```bash
kubectl apply -f deployment.yaml
```

**Expected output:**
```
deployment.apps/hello-world-python created
service/hello-world-python created
```

### Step 3: Verify Deployment

```bash
# Check deployment
kubectl get deployment hello-world-python

# Check pods
kubectl get pods -l app=hello-world-python

# Check service
kubectl get service hello-world-python
```

**Wait for pods to be ready:**
```bash
kubectl wait --for=condition=ready pod -l app=hello-world-python --timeout=2m
```

### Step 4: Access Application

**Get service IP:**
```bash
kubectl get service hello-world-python
```

**Test application:**
```bash
# Get the LoadBalancer IP or ClusterIP
SERVICE_IP=$(kubectl get service hello-world-python -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# If LoadBalancer IP is not available, use ClusterIP
if [ -z "$SERVICE_IP" ]; then
  SERVICE_IP=$(kubectl get service hello-world-python -o jsonpath='{.spec.clusterIP}')
fi

# Test endpoints
curl http://$SERVICE_IP/
curl http://$SERVICE_IP/health
curl http://$SERVICE_IP/ready
```

**Or use port-forward:**
```bash
kubectl port-forward service/hello-world-python 8080:80
curl http://localhost:8080/
```

## 🤖 Automated Deployment with Gitea Actions

### Step 1: Get K3s Kubeconfig

On K3s host:

```bash
# Get kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml

# Encode it to base64
sudo cat /etc/rancher/k3s/k3s.yaml | base64 -w 0
```

**Important:** Replace `127.0.0.1` with your K3s host IP in the kubeconfig:
```yaml
server: https://almak3s.lab.allwaysbeginner.com:6443
```

### Step 2: Add Kubeconfig Secret in Gitea

1. Go to repository → **Settings** → **Actions** → **Secrets**
2. Click **New secret**
3. Name: `KUBECONFIG`
4. Value: Paste the base64-encoded kubeconfig
5. Click **Add secret**

### Step 3: Use Automated Workflow

The workflow file `.gitea/workflows/build-push-deploy.yaml` includes three jobs:

1. **Test** - Tests the Python application
2. **Build-and-Push** - Builds and pushes Docker image
3. **Deploy** - Deploys to K3s automatically

**Trigger deployment:**
```bash
# Make a change
echo "# Update" >> README.md

# Commit and push
git add README.md
git commit -m "Trigger deployment"
git push
```

**Watch in Gitea:**
- Go to repository → **Actions**
- See the three jobs running
- Deploy job will update K3s automatically

## 📊 Kubernetes Resources

### Deployment Configuration

```yaml
Replicas: 2
Image: almabuild.lab.allwaysbeginner.com:3000/manfred/hello-world-python:latest
Port: 8080
Resources:
  Requests: 128Mi memory, 100m CPU
  Limits: 256Mi memory, 200m CPU
Probes:
  Liveness: /health (every 30s)
  Readiness: /ready (every 10s)
```

### Service Configuration

```yaml
Type: LoadBalancer
Port: 80 → 8080
Selector: app=hello-world-python
```

## 🔍 Monitoring and Troubleshooting

### Check Pod Status

```bash
# List pods
kubectl get pods -l app=hello-world-python

# Describe pod
kubectl describe pod <pod-name>

# View logs
kubectl logs -l app=hello-world-python -f

# View logs from specific pod
kubectl logs <pod-name> -f
```

### Check Service

```bash
# Get service details
kubectl get service hello-world-python -o wide

# Describe service
kubectl describe service hello-world-python

# Test service from within cluster
kubectl run test-curl --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -f http://hello-world-python.default.svc.cluster.local/health
```

### Check Deployment

```bash
# Get deployment status
kubectl get deployment hello-world-python

# Describe deployment
kubectl describe deployment hello-world-python

# View rollout status
kubectl rollout status deployment/hello-world-python

# View rollout history
kubectl rollout history deployment/hello-world-python
```

### Common Issues

#### 1. ImagePullBackOff

**Symptoms:**
```bash
kubectl get pods
# Shows: ImagePullBackOff or ErrImagePull
```

**Causes:**
- Registry secret not configured
- Wrong image name
- Registry not accessible from K3s

**Solutions:**
```bash
# Check secret exists
kubectl get secret gitea-registry

# Recreate secret
cd k8s
./setup-registry-secret.sh

# Check image name in deployment
kubectl get deployment hello-world-python -o yaml | grep image:

# Test registry access from K3s host
curl http://almabuild.lab.allwaysbeginner.com:3000
```

#### 2. CrashLoopBackOff

**Symptoms:**
```bash
kubectl get pods
# Shows: CrashLoopBackOff
```

**Causes:**
- Application error
- Port conflict
- Missing dependencies

**Solutions:**
```bash
# Check logs
kubectl logs <pod-name>

# Check events
kubectl describe pod <pod-name>

# Test image locally
docker run -p 8080:8080 almabuild.lab.allwaysbeginner.com:3000/manfred/hello-world-python:latest
```

#### 3. Service Not Accessible

**Symptoms:**
- Can't reach application via service IP

**Causes:**
- Service not created
- Wrong port mapping
- Network policy blocking

**Solutions:**
```bash
# Check service exists
kubectl get service hello-world-python

# Check endpoints
kubectl get endpoints hello-world-python

# Test from within cluster
kubectl run test-curl --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -v http://hello-world-python.default.svc.cluster.local/

# Check if pods are ready
kubectl get pods -l app=hello-world-python
```

#### 4. Deployment Fails in Workflow

**Symptoms:**
- Deploy job fails in Gitea Actions

**Causes:**
- KUBECONFIG secret not set
- Wrong kubeconfig format
- Network connectivity

**Solutions:**
```bash
# Verify secret exists in Gitea
# Repository → Settings → Actions → Secrets → KUBECONFIG

# Test kubeconfig locally
echo "$KUBECONFIG_BASE64" | base64 -d > /tmp/kubeconfig
export KUBECONFIG=/tmp/kubeconfig
kubectl get nodes

# Check runner can reach K3s
# On almabuild host:
curl -k https://almak3s.lab.allwaysbeginner.com:6443
```

## 🔄 Update Deployment

### Manual Update

```bash
# Update image tag
kubectl set image deployment/hello-world-python \
  hello-world-python=almabuild.lab.allwaysbeginner.com:3000/manfred/hello-world-python:NEW_TAG

# Or edit deployment
kubectl edit deployment hello-world-python

# Watch rollout
kubectl rollout status deployment/hello-world-python
```

### Automatic Update (via Workflow)

Just push code - the workflow will:
1. Build new image
2. Push to registry
3. Deploy to K3s automatically

```bash
git add .
git commit -m "Update application"
git push
```

## 🔧 Scaling

### Scale Replicas

```bash
# Scale to 3 replicas
kubectl scale deployment hello-world-python --replicas=3

# Verify
kubectl get pods -l app=hello-world-python
```

### Auto-scaling (Optional)

```bash
# Create HPA (Horizontal Pod Autoscaler)
kubectl autoscale deployment hello-world-python \
  --cpu-percent=70 \
  --min=2 \
  --max=10

# Check HPA
kubectl get hpa
```

## 🗑️ Cleanup

### Delete Application

```bash
# Delete deployment and service
kubectl delete -f k8s/deployment.yaml

# Or delete individually
kubectl delete deployment hello-world-python
kubectl delete service hello-world-python

# Delete registry secret
kubectl delete secret gitea-registry
```

### Verify Cleanup

```bash
kubectl get all -l app=hello-world-python
# Should show: No resources found
```

## 📈 Production Considerations

### 1. Resource Limits

Adjust based on your application needs:
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### 2. Multiple Environments

Create separate namespaces:
```bash
# Create namespaces
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace prod

# Deploy to specific namespace
kubectl apply -f k8s/deployment.yaml -n dev
```

### 3. Ingress Controller

For external access with domain names:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-python
spec:
  rules:
  - host: hello.lab.allwaysbeginner.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world-python
            port:
              number: 80
```

### 4. Persistent Storage

If your app needs storage:
```yaml
volumes:
- name: data
  persistentVolumeClaim:
    claimName: hello-world-data
```

### 5. ConfigMaps and Secrets

For configuration:
```bash
# Create ConfigMap
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info

# Use in deployment
env:
- name: APP_ENV
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: APP_ENV
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [K3s Documentation](https://docs.k3s.io/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

**Created with IBM Bob AI** 🤖