# Push Updates to Gitea

Quick guide to push all the new K8s deployment files to your Gitea repository.

## 📋 New Files to Push

### Kubernetes Manifests
- `k8s/deployment.yaml` - K8s deployment and service
- `k8s/setup-registry-secret.sh` - Registry secret setup
- `k8s/setup-remote-kubectl.sh` - Remote kubectl configuration

### Workflow
- `.gitea/workflows/build-push-deploy.yaml` - Full CI/CD pipeline

### Documentation
- `DEPLOYMENT_GUIDE.md` - Complete deployment guide
- `PUSH_UPDATES.md` - This file

## 🚀 Push to Gitea

### Step 1: Check Status

```bash
cd project-templates/hello-world-python

# See what's new/changed
git status
```

**Expected output:**
```
Untracked files:
  k8s/
  .gitea/workflows/build-push-deploy.yaml
  DEPLOYMENT_GUIDE.md
  PUSH_UPDATES.md

Modified files:
  .gitea/workflows/build-and-push.yaml (if you modified it)
```

### Step 2: Add Files

```bash
# Add all new files
git add k8s/
git add .gitea/workflows/build-push-deploy.yaml
git add DEPLOYMENT_GUIDE.md
git add PUSH_UPDATES.md

# Or add everything
git add .
```

### Step 3: Commit

```bash
git commit -m "Add K8s deployment and automated CI/CD

Features:
- Kubernetes deployment manifests (2 replicas, LoadBalancer)
- Registry secret setup script
- Remote kubectl configuration script
- Full CI/CD pipeline (test → build → deploy)
- Complete deployment guide

Architecture:
- Runner on almabuild deploys to almak3s remotely
- No runner needed on K3s host
- Automated deployment on every push

Created with IBM Bob AI"
```

### Step 4: Push

```bash
git push origin main
```

**Or if your branch is master:**
```bash
git push origin master
```

## 🔍 Verify in Gitea

After pushing, check in Gitea:

1. **Files Tab**
   - ✅ `k8s/` directory with 3 files
   - ✅ `.gitea/workflows/build-push-deploy.yaml`
   - ✅ `DEPLOYMENT_GUIDE.md`

2. **Actions Tab**
   - ✅ Workflow should trigger automatically
   - ✅ Watch the three jobs run:
     * Test
     * Build-and-push
     * Deploy (will fail until kubectl is configured)

3. **Packages Tab**
   - ✅ After successful build, image appears
   - ✅ Tagged with commit SHA and latest

## ⚠️ Expected Behavior

### First Push (Before kubectl Setup)

The workflow will:
- ✅ Test job: SUCCESS
- ✅ Build-and-push job: SUCCESS
- ❌ Deploy job: FAIL (kubectl not configured yet)

**This is expected!** The deploy job needs kubectl configured first.

### After kubectl Setup

Once you run `k8s/setup-remote-kubectl.sh` on almabuild:
- ✅ Test job: SUCCESS
- ✅ Build-and-push job: SUCCESS
- ✅ Deploy job: SUCCESS

## 🔧 Next Steps After Push

### 1. Configure kubectl on almabuild

```bash
# On almabuild host
cd project-templates/hello-world-python/k8s
chmod +x setup-remote-kubectl.sh
./setup-remote-kubectl.sh
```

### 2. Setup registry secret on almak3s

```bash
# On almak3s host
cd /path/to/k8s
chmod +x setup-registry-secret.sh
./setup-registry-secret.sh
```

### 3. Open firewall on almak3s

```bash
# On almak3s
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --reload
```

### 4. Test manual deployment

```bash
# On almabuild (after kubectl setup)
kubectl apply -f k8s/deployment.yaml
kubectl get pods -l app=hello-world-python
```

### 5. Trigger automated deployment

```bash
# Make a small change
echo "# Test" >> README.md

# Commit and push
git add README.md
git commit -m "Test automated deployment"
git push

# Watch in Gitea Actions tab
# All three jobs should succeed now!
```

## 📊 Workflow Comparison

### Old Workflow (build-and-push.yaml)
- ✅ Test
- ✅ Build and push image
- ❌ No deployment

### New Workflow (build-push-deploy.yaml)
- ✅ Test
- ✅ Build and push image
- ✅ Deploy to K3s automatically

## 🎯 Summary

```bash
# Quick commands
cd project-templates/hello-world-python
git add .
git commit -m "Add K8s deployment and CI/CD"
git push origin main

# Then setup kubectl and try again
```

After push:
1. ✅ Files in Gitea
2. ✅ Workflow runs (deploy fails until kubectl setup)
3. ✅ Setup kubectl on almabuild
4. ✅ Push again - full automation works!

---

**Ready to push? Run the commands above!** 🚀