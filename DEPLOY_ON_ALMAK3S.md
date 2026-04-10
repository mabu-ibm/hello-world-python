# Deploy Secure Application on almak3s

Quick guide to deploy the secure Hello World Python application directly on almak3s.

## 🚀 Quick Start (Choose One Method)

### Method 1: Standalone Script (Recommended - No Repo Needed)

This method works without cloning the repository. Just copy the script to almak3s.

#### Step 1: Copy Script to almak3s

```bash
# On your MacBook
scp project-templates/hello-world-python/k8s/deploy-secure-standalone.sh root@almak3s:/tmp/
```

#### Step 2: Run on almak3s

```bash
# SSH to almak3s
ssh root@almak3s

# Run the script
cd /tmp
chmod +x deploy-secure-standalone.sh
./deploy-secure-standalone.sh
```

The script will:
- ✅ Install kubectl if needed
- ✅ Setup kubeconfig
- ✅ Create all manifests inline
- ✅ Deploy secure application
- ✅ Verify security settings
- ✅ Show access information

**Time:** 2-3 minutes

---

### Method 2: With Repository (Full Setup)

This method clones the repository and gives you access to all scripts and documentation.

#### Step 1: Setup Prerequisites

```bash
# On your MacBook - copy setup script
scp k8s-setup/setup-almak3s-prerequisites.sh root@almak3s:/tmp/

# SSH to almak3s
ssh root@almak3s

# Run prerequisites setup
cd /tmp
chmod +x setup-almak3s-prerequisites.sh
./setup-almak3s-prerequisites.sh
```

This will:
- Install kubectl
- Setup kubeconfig
- Install git
- Clone repository (you'll be prompted for Gitea URL)

#### Step 2: Deploy Application

```bash
# After prerequisites are installed
cd /root/dev-infrastructure-setup/project-templates/hello-world-python/k8s

# Option A: Automated deployment
./setup-secure-deployment.sh

# Option B: Manual deployment
kubectl apply -f deployment-secure.yaml
kubectl apply -f network-policy.yaml
```

**Time:** 5-10 minutes

---

## 📋 Prerequisites

### What You Need

1. **K3s installed** on almak3s
   ```bash
   systemctl status k3s
   ```

2. **Registry secret** created (if using private registry)
   ```bash
   kubectl get secret gitea-registry
   ```

3. **Docker image** built and pushed to registry
   - Image should be at: `almabuild.lab.allwaysbeginner.com:3000/USERNAME/hello-world-python:latest`

### If Prerequisites Missing

**Install K3s:**
```bash
curl -sfL https://get.k3s.io | sh -
```

**Create Registry Secret:**
```bash
kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild.lab.allwaysbeginner.com:3000 \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  --namespace=default
```

---

## 🔍 Verification

### Check Deployment

```bash
# Check pods
kubectl get pods -l app=hello-world-python

# Expected output:
# NAME                                  READY   STATUS    RESTARTS   AGE
# hello-world-python-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
# hello-world-python-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

### Verify Security

```bash
# Get pod name
POD=$(kubectl get pod -l app=hello-world-python -o jsonpath='{.items[0].metadata.name}')

# 1. Check user ID (should be 1000)
kubectl exec $POD -- id
# Expected: uid=1000(appuser) gid=1000(appuser)

# 2. Check read-only filesystem (should fail)
kubectl exec $POD -- touch /test
# Expected: touch: cannot touch '/test': Read-only file system

# 3. Check health endpoint
kubectl exec $POD -- curl -s http://localhost:8080/health
# Expected: {"status": "healthy"}
```

### Test Application

```bash
# Get service IP
SERVICE_IP=$(kubectl get service hello-world-python -o jsonpath='{.spec.clusterIP}')

# Test from almak3s
curl http://$SERVICE_IP/
curl http://$SERVICE_IP/health

# Or use port-forward
kubectl port-forward service/hello-world-python 8080:80 &
curl http://localhost:8080/
```

---

## 🔧 Troubleshooting

### Issue: kubectl not found

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
sudo ln -sf /usr/local/bin/kubectl /usr/bin/kubectl
```

### Issue: kubeconfig not configured

```bash
# Setup kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Test
kubectl get nodes
```

### Issue: ImagePullBackOff

```bash
# Check if registry secret exists
kubectl get secret gitea-registry

# If missing, create it
kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild.lab.allwaysbeginner.com:3000 \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD

# Check K3s registry config
sudo cat /etc/rancher/k3s/registries.yaml

# Should contain:
# mirrors:
#   almabuild.lab.allwaysbeginner.com:3000:
#     endpoint:
#       - "http://almabuild.lab.allwaysbeginner.com:3000"
```

### Issue: Pods CrashLoopBackOff

```bash
# Check logs
kubectl logs -l app=hello-world-python --tail=50

# Check events
kubectl describe pod -l app=hello-world-python

# Common causes:
# - Missing writable volumes (/tmp, /home/appuser/.cache)
# - Application errors
# - Resource limits too low
```

### Issue: Network Policy Blocks Traffic

```bash
# Temporarily remove network policy to test
kubectl delete networkpolicy hello-world-python-netpol

# Test application
kubectl port-forward service/hello-world-python 8080:80
curl http://localhost:8080/

# Re-apply network policy
kubectl apply -f network-policy.yaml
```

---

## 📊 What Gets Deployed

### Resources Created

1. **Deployment** - 2 replicas with security contexts
2. **Service** - ClusterIP for internal access
3. **ServiceAccount** - Dedicated service account
4. **ConfigMap** - Non-sensitive configuration
5. **Secret** - Sensitive data (placeholder)
6. **NetworkPolicy** - Network isolation rules

### Security Features

- ✅ Non-root user (UID 1000)
- ✅ Read-only root filesystem
- ✅ Dropped all capabilities
- ✅ Security contexts (pod + container)
- ✅ Network policies
- ✅ Resource limits
- ✅ Health probes
- ✅ Service account

---

## 🎯 Quick Commands Reference

```bash
# Deploy
./deploy-secure-standalone.sh

# Check status
kubectl get all -l app=hello-world-python

# View logs
kubectl logs -l app=hello-world-python -f

# Test application
kubectl port-forward service/hello-world-python 8080:80
curl http://localhost:8080/

# Scale
kubectl scale deployment hello-world-python --replicas=3

# Update image
kubectl set image deployment/hello-world-python \
  hello-world-python=almabuild.lab.allwaysbeginner.com:3000/USERNAME/hello-world-python:v2

# Rollback
kubectl rollout undo deployment/hello-world-python

# Delete
kubectl delete deployment hello-world-python
kubectl delete service hello-world-python
kubectl delete networkpolicy hello-world-python-netpol
```

---

## 📚 Additional Resources

- **Security Guide:** [SECURITY_SETUP.md](SECURITY_SETUP.md)
- **Full Security Hardening:** [../../docs/SECURITY_HARDENING_GUIDE.md](../../docs/SECURITY_HARDENING_GUIDE.md)
- **Infrastructure Guide:** [../../docs/COMPLETE_INFRASTRUCTURE_GUIDE.md](../../docs/COMPLETE_INFRASTRUCTURE_GUIDE.md)

---

## 🚦 Deployment Checklist

Before deploying:
- [ ] K3s is running on almak3s
- [ ] kubectl is installed and configured
- [ ] Registry secret exists (gitea-registry)
- [ ] Docker image is built and pushed
- [ ] Network connectivity to registry

After deploying:
- [ ] Pods are running (2/2)
- [ ] Service is created
- [ ] Network policy is applied
- [ ] Security checks pass
- [ ] Application responds to health checks
- [ ] Can access application via ClusterIP

---

**Deployment Time:** 2-10 minutes (depending on method)

**Security Level:** 🔒🔒🔒🔒🔒 Enterprise-Grade

**Maintenance:** Low (automated)

---

**Created with IBM Bob AI** 🤖