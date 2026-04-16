# Complete Gitea Secrets Setup and Troubleshooting Guide

## Problem: Workflow Runs Without Secrets / 404 Error on HTTP

### Root Causes:
1. **Workflow runs without secrets** - No validation was in place
2. **404 on HTTP** - Ingress not properly configured or DNS issue
3. **App generated incorrectly** - Missing or wrong secrets

## Solution Overview

✅ **Added secret validation** - Workflow now fails fast if secrets missing  
✅ **Created diagnostic script** - Identifies ingress issues  
✅ **Flexible ingress** - Accepts both HTTP and HTTPS  

---

## Part 1: Setting Up Gitea Secrets

### Step 1: Navigate to Secrets Settings

```
Gitea Repository → Settings → Secrets → Actions
```

### Step 2: Add Required Secrets

#### 1. GIT_REGISTRY
```
Name: GIT_REGISTRY
Value: almabuild2.lab.allwaysbeginner.com:5000
```
**Purpose:** Docker registry URL for pushing/pulling images

#### 2. GIT_USERNAME
```
Name: GIT_USERNAME
Value: your-gitea-username
```
**Purpose:** Username for registry authentication

#### 3. GIT_TOKEN
```
Name: GIT_TOKEN
Value: your-gitea-token-or-password
```
**Purpose:** Password/token for registry authentication

**How to get token:**
```
Gitea → Settings → Applications → Generate New Token
```

#### 4. KUBECONFIG
```
Name: KUBECONFIG
Value: <base64-encoded-kubeconfig-or-plain-text>
```

**How to get kubeconfig:**

**Option A: Base64 Encoded (Recommended)**
```bash
# On K3s node
cat /etc/rancher/k3s/k3s.yaml | base64 -w 0

# Or from your machine
cat ~/.kube/config | base64 -w 0
```

**Option B: Plain Text**
```bash
# Copy content of kubeconfig file
cat /etc/rancher/k3s/k3s.yaml
```

**Important:** Update the server URL in kubeconfig:
```yaml
server: https://127.0.0.1:6443  # Change to actual K3s IP
# Should be:
server: https://192.168.1.100:6443  # Your K3s node IP
```

#### 5. INGRESS_HOST (Required)
```
Name: INGRESS_HOST
Value: hello-world-python.lab.allwaysbeginner.com
```
**Purpose:** Hostname for ingress - the URL where your app will be accessible

**Important:** This must match the hostname you'll use to access the app

### Step 3: Verify Secrets

After adding secrets, they should appear in the list:
```
✓ GIT_REGISTRY
✓ GIT_USERNAME
✓ GIT_TOKEN
✓ KUBECONFIG
✓ INGRESS_HOST
```

**All 5 secrets are required for the workflow to run!**

---

## Part 2: Workflow Validation

### New Validation Step

The workflow now includes **Step 0: Validate Required Secrets**

**What it does:**
- Checks if all required secrets are set
- Fails immediately if any are missing
- Shows clear error message with instructions

**Example Output (Missing Secrets):**
```
❌ Missing secret: GIT_REGISTRY
❌ Missing secret: KUBECONFIG
⚠️  Optional secret INGRESS_HOST not set (will use default)

============================================
❌ WORKFLOW FAILED: Missing Required Secrets
============================================

Missing secrets: GIT_REGISTRY KUBECONFIG

Please add these secrets in Gitea:
  Repository → Settings → Secrets → Actions

Required secrets:
  - GIT_REGISTRY: Registry URL
  - GIT_USERNAME: Registry username
  - GIT_TOKEN: Registry password/token
  - KUBECONFIG: Kubernetes config
```

**Example Output (All Secrets Set):**
```
✓ GIT_REGISTRY is set
✓ GIT_USERNAME is set
✓ GIT_TOKEN is set
✓ KUBECONFIG is set
✓ INGRESS_HOST is set: hello-world-python.lab.allwaysbeginner.com

✅ All 5 required secrets are configured
============================================
```

**Note:** INGRESS_HOST is now required (not optional) to ensure proper ingress configuration.

---

## Part 3: Troubleshooting 404 Error

### Quick Diagnosis

Run the diagnostic script:
```bash
chmod +x k8s/diagnose-ingress.sh
./k8s/diagnose-ingress.sh hello-world-python.lab.allwaysbeginner.com
```

### Common Causes of 404

#### Issue 1: Ingress Host Mismatch

**Problem:** Ingress configured for different hostname than you're accessing

**Check:**
```bash
kubectl get ingress -n default -o yaml | grep host
```

**Should show:**
```yaml
host: hello-world-python.lab.allwaysbeginner.com
```

**If it shows `${INGRESS_HOST}`:**
```yaml
host: ${INGRESS_HOST}  # ❌ Variable not replaced!
```

**Fix:**
```bash
# Redeploy with proper variable substitution
INGRESS_HOST="hello-world-python.lab.allwaysbeginner.com"
sed "s/\${INGRESS_HOST}/${INGRESS_HOST}/g" k8s/ingress-flexible.yaml | kubectl apply -f -
```

#### Issue 2: DNS Not Configured

**Problem:** Hostname doesn't resolve to cluster IP

**Check:**
```bash
nslookup hello-world-python.lab.allwaysbeginner.com
# or
ping hello-world-python.lab.allwaysbeginner.com
```

**Fix:** Add to /etc/hosts
```bash
# Get cluster IP
kubectl get nodes -o wide

# Add to /etc/hosts
echo "192.168.1.100  hello-world-python.lab.allwaysbeginner.com" | sudo tee -a /etc/hosts
```

#### Issue 3: Service Not Found

**Problem:** Service doesn't exist or has no endpoints

**Check:**
```bash
kubectl get service hello-world-python -n default
kubectl get endpoints hello-world-python -n default
```

**Fix:**
```bash
# Redeploy application
kubectl apply -f k8s/deployment.yaml
```

#### Issue 4: Pods Not Running

**Problem:** Application pods are not running

**Check:**
```bash
kubectl get pods -n default -l app=hello-world-python
```

**Fix:**
```bash
# Check pod logs
kubectl logs -n default -l app=hello-world-python

# Check pod events
kubectl describe pods -n default -l app=hello-world-python
```

#### Issue 5: Wrong Namespace

**Problem:** Resources deployed to different namespace

**Check:**
```bash
# Check all namespaces
kubectl get ingress -A
kubectl get pods -A | grep hello-world
```

**Fix:**
```bash
# Ensure using correct namespace
kubectl get all -n default | grep hello-world
```

### Testing Access

#### Test 1: Direct Pod Access
```bash
# Get pod name
POD=$(kubectl get pods -n default -l app=hello-world-python -o jsonpath='{.items[0].metadata.name}')

# Test pod directly
kubectl exec -n default $POD -- wget -q -O- http://localhost:8080
```

#### Test 2: Service Access (Within Cluster)
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  wget -q -O- http://hello-world-python.default.svc.cluster.local
```

#### Test 3: Ingress Access (HTTP)
```bash
curl -v http://hello-world-python.lab.allwaysbeginner.com
```

#### Test 4: Ingress Access (HTTPS)
```bash
curl -kv https://hello-world-python.lab.allwaysbeginner.com
```

#### Test 5: Direct IP with Host Header
```bash
# Bypass DNS
CLUSTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
curl -v http://${CLUSTER_IP} -H 'Host: hello-world-python.lab.allwaysbeginner.com'
```

---

## Part 4: Complete Deployment Checklist

### Pre-Deployment
- [ ] All Gitea secrets configured
- [ ] KUBECONFIG has correct server IP
- [ ] DNS or /etc/hosts configured
- [ ] K3s cluster is accessible

### Deployment
- [ ] Workflow validation passes
- [ ] Docker image builds successfully
- [ ] Image pushes to registry
- [ ] Deployment creates pods
- [ ] Pods are running
- [ ] Service is created
- [ ] Ingress is created
- [ ] TLS certificate is created

### Post-Deployment
- [ ] Pods show as Running
- [ ] Service has endpoints
- [ ] Ingress shows ADDRESS
- [ ] HTTP access works
- [ ] HTTPS access works

### Verification Commands

```bash
# 1. Check workflow ran successfully
# (Check in Gitea Actions tab)

# 2. Check pods
kubectl get pods -n default -l app=hello-world-python

# 3. Check service
kubectl get service hello-world-python -n default

# 4. Check ingress
kubectl get ingress -n default

# 5. Check ingress details
kubectl describe ingress -n default

# 6. Test HTTP
curl http://hello-world-python.lab.allwaysbeginner.com

# 7. Test HTTPS
curl -k https://hello-world-python.lab.allwaysbeginner.com
```

---

## Part 5: Quick Fixes

### Fix 1: Redeploy Everything
```bash
# Delete existing resources
kubectl delete -f k8s/deployment.yaml
kubectl delete ingress -n default --all

# Redeploy
INGRESS_HOST="hello-world-python.lab.allwaysbeginner.com"
IMAGE_REGISTRY="almabuild2.lab.allwaysbeginner.com:5000"

sed -e "s/\${IMAGE_REGISTRY}/${IMAGE_REGISTRY}/g" \
    -e "s/\${IMAGE_REPOSITORY}/hello-world-python/g" \
    -e "s/\${IMAGE_TAG}/latest/g" \
    k8s/deployment.yaml | kubectl apply -f -

sed "s/\${INGRESS_HOST}/${INGRESS_HOST}/g" \
    k8s/ingress-flexible.yaml | kubectl apply -f -
```

### Fix 2: Use Deployment Script
```bash
chmod +x k8s/deploy-flexible.sh
./k8s/deploy-flexible.sh \
  hello-world-python.lab.allwaysbeginner.com \
  almabuild2.lab.allwaysbeginner.com:5000
```

### Fix 3: Check Traefik Logs
```bash
# View Traefik logs for routing issues
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik -f
```

---

## Part 6: Example Complete Setup

### Step-by-Step Example

```bash
# 1. Set up secrets in Gitea
# (Use Gitea UI as described above)

# 2. Configure /etc/hosts
echo "192.168.1.100  hello-world-python.lab.allwaysbeginner.com" | sudo tee -a /etc/hosts

# 3. Push code to trigger workflow
git add .
git commit -m "Deploy with secrets"
git push

# 4. Wait for workflow to complete
# (Check Gitea Actions tab)

# 5. Verify deployment
kubectl get all -n default | grep hello-world

# 6. Test access
curl http://hello-world-python.lab.allwaysbeginner.com
curl -k https://hello-world-python.lab.allwaysbeginner.com

# 7. If 404, run diagnostics
./k8s/diagnose-ingress.sh hello-world-python.lab.allwaysbeginner.com
```

---

## Summary

✅ **Workflow now validates secrets** - Won't run without them  
✅ **Diagnostic script available** - Quickly identify issues  
✅ **Flexible ingress** - HTTP and HTTPS both work  
✅ **Clear error messages** - Know exactly what's wrong  
✅ **Complete troubleshooting** - Fix any deployment issue  

## Made with Bob