# Troubleshooting almabuild2 Registry Access

## Problem
Kubernetes pods fail to pull images from the new almabuild2 registry with error:
```
Error from server (BadRequest): container "hello-world-python" in pod "hello-world-python-6b76876d77-srjg7" is waiting to start: trying and failing to pull image
```

## Root Causes

This error typically occurs due to one or more of these issues:

1. **Missing imagePullSecrets** - Kubernetes doesn't have credentials to pull from private registry
2. **Network connectivity** - K8s nodes can't reach almabuild2:5000
3. **Insecure registry not configured** - Docker on K8s nodes doesn't trust the registry
4. **Wrong image reference** - Deployment uses old registry (almabuild) instead of new one (almabuild2)
5. **Firewall blocking** - Port 5000 blocked on almabuild2

---

## Quick Fix (Automated)

Run the automated fix script:

```bash
cd k8s
chmod +x fix-registry-access-almabuild2.sh

# Set your registry password
export REGISTRY_PASSWORD='your-gitea-password'

# Run the fix script
./fix-registry-access-almabuild2.sh
```

This script will:
- ✅ Test registry connectivity
- ✅ Create Kubernetes secret with registry credentials
- ✅ Patch existing deployment to use the secret
- ✅ Verify image pull works

---

## Manual Fix (Step-by-Step)

### Step 1: Verify Gitea and Registry are Running on almabuild2

```bash
# SSH to almabuild2
ssh almabuild2

# Check if Gitea service is running (native installation)
sudo systemctl status gitea

# Should show: Active: active (running)

# Test Gitea web interface
curl http://localhost:3000
# Should return HTML

# Test registry endpoint (Gitea's built-in registry)
curl http://localhost:3000/v2/
# Should return: {} or authentication required message
```

**If Gitea is not running:**
```bash
# Start Gitea service
sudo systemctl start gitea
sudo systemctl enable gitea
sudo systemctl status gitea

# Check Gitea logs if issues
sudo journalctl -u gitea -n 50 -f
```

**Verify Gitea Registry is Enabled:**
```bash
# Check Gitea configuration
sudo cat /etc/gitea/app.ini | grep -A 10 "\[packages\]"

# Should show:
# [packages]
# ENABLED = true
```

### Step 2: Check Firewall on almabuild2

```bash
# SSH to almabuild2
ssh almabuild2

# Check if port 5000 is open
sudo firewall-cmd --list-all

# If port 5000 is not listed, add it:
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-ports
```

### Step 3: Test Registry Access from K8s Cluster

**Important:** Gitea's registry runs on port 3000, not 5000. The registry path is `/v2/`.

```bash
# From your K8s master or any node
curl http://almabuild2:3000/v2/

# Should return: {} or authentication required

# Test with authentication
curl -u manfred:your-token http://almabuild2:3000/v2/

# If it fails, check DNS/hosts file
cat /etc/hosts | grep almabuild2

# Should have entry like:
# 192.168.1.100  almabuild2

# Test basic connectivity
ping almabuild2
telnet almabuild2 3000
```

### Step 4: Configure Insecure Registry on K8s Nodes

**IMPORTANT:** This must be done on ALL Kubernetes nodes (master and workers).

**For Gitea's native registry, use port 3000:**

```bash
# SSH to each K8s node
ssh <k8s-node>

# Edit Docker daemon config
sudo nano /etc/docker/daemon.json

# Add or update to include:
{
  "insecure-registries": ["almabuild2:3000", "almabuild:5000"],
  "registry-mirrors": []
}

# Save and restart Docker
sudo systemctl restart docker

# Verify Docker restarted successfully
sudo systemctl status docker

# Test registry access (use Gitea credentials)
echo 'your-gitea-token' | docker login almabuild2:3000 -u manfred --password-stdin
docker pull almabuild2:3000/manfred/hello-world-python:latest
```

**For K3s (if using K3s instead of Docker):**
```bash
# Edit K3s registries config
sudo nano /etc/rancher/k3s/registries.yaml

# Add (note: port 3000 for Gitea):
mirrors:
  "almabuild2:3000":
    endpoint:
      - "http://almabuild2:3000"
configs:
  "almabuild2:3000":
    auth:
      username: manfred
      password: your-gitea-token
    tls:
      insecure_skip_verify: true

# Restart K3s
sudo systemctl restart k3s
```

### Step 5: Create Kubernetes Registry Secret

```bash
# Create secret with registry credentials (use port 3000 for Gitea)
kubectl create secret docker-registry registry-credentials \
  --docker-server=almabuild2:3000 \
  --docker-username=manfred \
  --docker-password='your-gitea-token' \
  --namespace=default

# Verify secret was created
kubectl get secret registry-credentials -n default

# View secret details (base64 encoded)
kubectl get secret registry-credentials -n default -o yaml
```

**Note:** Use your Gitea access token, not your Gitea password. Generate a token in Gitea:
1. Go to Gitea → Settings → Applications → Generate New Token
2. Give it a name like "kubernetes-registry"
3. Select scopes: `read:package`, `write:package`
4. Copy the token and use it as the password

### Step 6: Update Deployment to Use Registry Secret

Check your current deployment:

```bash
# View current deployment
kubectl get deployment hello-world-python -n default -o yaml
```

The deployment MUST include `imagePullSecrets`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-python
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-world-python
  template:
    metadata:
      labels:
        app: hello-world-python
    spec:
      imagePullSecrets:              # ← ADD THIS
      - name: registry-credentials   # ← ADD THIS
      containers:
      - name: hello-world-python
        image: almabuild2:3000/manfred/hello-world-python:latest  # ← UPDATE THIS (port 3000)
        ports:
        - containerPort: 5000
```

**Update existing deployment:**

```bash
# Option 1: Patch the deployment
kubectl patch deployment hello-world-python -n default -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"registry-credentials"}]}}}}'

# Option 2: Edit directly
kubectl edit deployment hello-world-python -n default
# Add imagePullSecrets section manually

# Option 3: Apply updated YAML
kubectl apply -f k8s/deployment.yaml
```

### Step 7: Update Image Reference

If your deployment still references the old registry (almabuild), update it:

```bash
# Update image to use almabuild2 (port 3000 for Gitea registry)
kubectl set image deployment/hello-world-python \
  hello-world-python=almabuild2:3000/manfred/hello-world-python:latest \
  -n default

# Or edit the deployment YAML and apply
nano k8s/deployment.yaml
# Change image: almabuild:5000/... to almabuild2:3000/...
kubectl apply -f k8s/deployment.yaml
```

### Step 8: Verify Deployment

```bash
# Check pod status
kubectl get pods -n default

# Should show Running status
# NAME                                  READY   STATUS    RESTARTS   AGE
# hello-world-python-6b76876d77-srjg7   1/1     Running   0          2m

# If still failing, check pod events
kubectl describe pod hello-world-python-6b76876d77-srjg7 -n default

# Check pod logs
kubectl logs hello-world-python-6b76876d77-srjg7 -n default
```

---

## Verification Checklist

Use this checklist to verify everything is configured correctly:

- [ ] Registry is running on almabuild2: `ssh almabuild2 'docker ps | grep registry'`
- [ ] Port 5000 is open on almabuild2: `ssh almabuild2 'sudo firewall-cmd --list-ports'`
- [ ] Registry is accessible from K8s nodes: `curl http://almabuild2:5000/v2/`
- [ ] Docker daemon.json includes almabuild2:5000 in insecure-registries
- [ ] Docker restarted on all K8s nodes: `sudo systemctl restart docker`
- [ ] Kubernetes secret exists: `kubectl get secret registry-credentials -n default`
- [ ] Deployment has imagePullSecrets: `kubectl get deployment hello-world-python -n default -o yaml | grep imagePullSecrets`
- [ ] Image reference uses almabuild2: `kubectl get deployment hello-world-python -n default -o jsonpath='{.spec.template.spec.containers[0].image}'`
- [ ] Pods are running: `kubectl get pods -n default`

---

## Common Errors and Solutions

### Error: "x509: certificate signed by unknown authority"

**Cause:** Registry uses self-signed certificate

**Solution:**
```bash
# On each K8s node
sudo mkdir -p /etc/docker/certs.d/almabuild2:5000
sudo scp almabuild2:/path/to/cert.crt /etc/docker/certs.d/almabuild2:5000/ca.crt
sudo systemctl restart docker
```

### Error: "dial tcp: lookup almabuild2: no such host"

**Cause:** DNS resolution failing

**Solution:**
```bash
# Add to /etc/hosts on all K8s nodes
echo "192.168.1.100  almabuild2" | sudo tee -a /etc/hosts
```

### Error: "unauthorized: authentication required"

**Cause:** Missing or incorrect credentials

**Solution:**
```bash
# Delete and recreate secret with correct credentials
kubectl delete secret registry-credentials -n default
kubectl create secret docker-registry registry-credentials \
  --docker-server=almabuild2:5000 \
  --docker-username=manfred \
  --docker-password='correct-password' \
  --namespace=default
```

### Error: "http: server gave HTTP response to HTTPS client"

**Cause:** Docker trying HTTPS but registry is HTTP

**Solution:**
```bash
# Ensure insecure-registries is configured
sudo nano /etc/docker/daemon.json
# Add: "insecure-registries": ["almabuild2:5000"]
sudo systemctl restart docker
```

---

## Testing Image Pull Manually

Test if you can pull the image manually from a K8s node:

```bash
# SSH to a K8s node
ssh <k8s-node>

# Try to pull the image
docker pull almabuild2:5000/manfred/hello-world-python:latest

# If successful, you should see:
# latest: Pulling from manfred/hello-world-python
# ...
# Status: Downloaded newer image for almabuild2:5000/manfred/hello-world-python:latest
```

If manual pull works but Kubernetes still fails, the issue is with the Kubernetes secret or deployment configuration.

---

## Update Gitea Secrets

If you're using Gitea Actions workflows, update the secrets:

1. Go to Gitea repository → Settings → Secrets
2. Update or add these secrets:
   - `GIT_REGISTRY`: `almabuild2:5000`
   - `GIT_USERNAME`: `manfred`
   - `GIT_TOKEN`: Your Gitea access token
   - `KUBECONFIG`: Your kubeconfig (base64 encoded)

3. Re-run the workflow to build and push to the new registry

---

## Network Diagram

```
┌─────────────────┐
│   Developer     │
│   Machine       │
└────────┬────────┘
         │
         │ git push
         ▼
┌─────────────────┐
│   almabuild2    │
│   (New Server)  │
│                 │
│  ┌───────────┐  │
│  │  Gitea    │  │
│  │  :3000    │  │
│  └───────────┘  │
│                 │
│  ┌───────────┐  │
│  │ Registry  │  │
│  │  :5000    │  │◄─── Kubernetes nodes must reach this
│  └───────────┘  │
│                 │
│  ┌───────────┐  │
│  │  Runner   │  │
│  └───────────┘  │
└─────────────────┘
         │
         │ kubectl apply
         ▼
┌─────────────────┐
│  Kubernetes     │
│  Cluster        │
│                 │
│  ┌───────────┐  │
│  │   Pods    │  │
│  │  (pull    │  │
│  │  images)  │  │
│  └───────────┘  │
└─────────────────┘
```

---

## Prevention for Future

To avoid this issue when adding new registries:

1. **Always configure insecure-registries** on all K8s nodes before deploying
2. **Create registry secret** before first deployment
3. **Include imagePullSecrets** in deployment YAML from the start
4. **Test image pull manually** before deploying to K8s
5. **Document registry changes** in your team

---

## Quick Reference Commands

```bash
# Check pod status
kubectl get pods -n default

# Describe pod (shows events and errors)
kubectl describe pod <pod-name> -n default

# Check deployment image
kubectl get deployment hello-world-python -n default -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check if secret exists
kubectl get secret registry-credentials -n default

# Test registry from K8s node
ssh <k8s-node> 'docker pull almabuild2:5000/manfred/hello-world-python:latest'

# View pod logs
kubectl logs <pod-name> -n default

# Force pod restart
kubectl rollout restart deployment/hello-world-python -n default

# Delete failed pods
kubectl delete pod <pod-name> -n default --force --grace-period=0
```

---

## Need More Help?

If you're still experiencing issues:

1. Run the automated fix script: `./k8s/fix-registry-access-almabuild2.sh`
2. Check all items in the verification checklist above
3. Review pod events: `kubectl describe pod <pod-name>`
4. Check node logs: `ssh <k8s-node> 'sudo journalctl -u docker -n 100'`
5. Verify network connectivity: `ssh <k8s-node> 'curl http://almabuild2:5000/v2/'`

Made with ❤️ by IBM Bob