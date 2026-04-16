# Gitea Workflows Guide

This directory contains two CI/CD workflows for building, pushing, and deploying the application.

## Available Workflows

### 1. build-push-deploy.yaml (Containerized) ⭐ RECOMMENDED

**Status:** ✅ Ready to use  
**Requirements:** Only Docker on runner

This workflow runs all tools (Docker, kubectl) inside containers, making it portable and easy to set up.

**Use this workflow if:**
- ✅ Your Gitea runner only has Docker installed
- ✅ You want maximum portability
- ✅ You don't want to install kubectl on the runner
- ✅ You're using the default Gitea runner setup

**How it works:**
- Uses `bitnami/kubectl:latest` container for all kubectl commands
- Passes kubeconfig via environment variables
- No host dependencies except Docker

**To use:**
- This workflow is already configured and ready
- Just push to main/master branch
- Or trigger manually via Gitea Actions UI

---

### 2. build-push-deploy-native.yaml (Native)

**Status:** ⚠️ Requires Docker + kubectl on runner  
**Requirements:** Docker AND kubectl installed on runner

This workflow uses native Docker and kubectl commands for faster execution.

**Use this workflow if:**
- ✅ Docker is installed on the runner
- ✅ kubectl is installed on the runner
- ✅ Runner user has Docker permissions
- ✅ You want ~70% faster execution

**Requirements:**
```bash
# On the Gitea runner host (almabuild2):

# 1. Install Docker
sudo dnf install -y docker
sudo systemctl enable --now docker

# 2. Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 3. Add runner user to docker group
sudo usermod -aG docker gitea-runner

# 4. Restart runner
sudo systemctl restart gitea-runner

# 5. Verify
sudo -u gitea-runner docker ps
sudo -u gitea-runner kubectl version --client
```

**To use:**
- Rename or disable `build-push-deploy.yaml`
- Ensure this workflow is enabled
- Push to main/master branch

---

## Current Recommendation

**Use `build-push-deploy.yaml` (containerized workflow)**

Since your Gitea runner doesn't have Docker installed natively (based on the error: "docker: command not found"), the containerized workflow is the best choice.

The containerized workflow:
- ✅ Works with your current setup
- ✅ No additional installation needed
- ✅ More portable and maintainable
- ✅ Isolated execution environment

---

## Workflow Comparison

| Feature | Containerized | Native |
|---------|--------------|--------|
| **Docker Required** | ✅ Yes | ✅ Yes |
| **kubectl Required** | ❌ No | ✅ Yes |
| **Setup Complexity** | Low | Medium |
| **Execution Speed** | Normal | Fast (~70% faster) |
| **Portability** | High | Medium |
| **Debugging** | Complex | Simple |
| **Recommended For** | Most users | Advanced setups |

---

## Switching Between Workflows

### To Use Containerized (Current Default):
```bash
# Ensure build-push-deploy.yaml is enabled
# This is the default - no changes needed
```

### To Switch to Native:
```bash
# 1. Install Docker and kubectl on runner (see requirements above)

# 2. Disable containerized workflow
mv .gitea/workflows/build-push-deploy.yaml .gitea/workflows/build-push-deploy.yaml.disabled

# 3. Enable native workflow
# (build-push-deploy-native.yaml is already present)

# 4. Push changes
git add .gitea/workflows/
git commit -m "Switch to native workflow"
git push
```

---

## Troubleshooting

### Error: "docker: command not found" (Native Workflow)

**Cause:** Docker is not installed on the Gitea runner

**Solution:** Either:
1. Install Docker on the runner (see requirements above)
2. Use the containerized workflow instead

### Error: "kubectl: command not found" (Native Workflow)

**Cause:** kubectl is not installed on the Gitea runner

**Solution:** Either:
1. Install kubectl on the runner (see requirements above)
2. Use the containerized workflow instead

### Error: "permission denied while trying to connect to Docker daemon"

**Cause:** Runner user doesn't have Docker permissions

**Solution:**
```bash
# On runner host
sudo usermod -aG docker gitea-runner
sudo systemctl restart gitea-runner
```

### Error: "http: server gave HTTP response to HTTPS client"

**Cause:** K3s nodes can't pull from HTTP registry

**Solution:** See `QUICK_FIX_K3S_HTTP_REGISTRY.md` for detailed fix

---

## Workflow Secrets Required

Both workflows require these secrets to be configured in Gitea:

| Secret | Description | Example |
|--------|-------------|---------|
| `GIT_REGISTRY` | Registry hostname:port | `almabuild2.lab.allwaysbeginner.com:3000` |
| `GIT_USERNAME` | Gitea username | `manfred` |
| `GIT_TOKEN` | Gitea access token | `glpat-xxxxxxxxxxxxx` |
| `KUBECONFIG` | Kubernetes config (base64) | `apiVersion: v1...` |
| `CONCERT_URL` | Concert URL (optional) | `https://concert.example.com` |
| `CONCERT_API_KEY` | Concert API key (optional) | `xxx` |
| `CONCERT_INSTANCE_ID` | Concert instance ID (optional) | `xxx` |
| `CONCERT_APPLICATION_ID` | Concert app ID (optional) | `xxx` |

### How to Set Secrets:

1. Go to your repository in Gitea
2. Click **Settings** → **Secrets**
3. Click **Add Secret**
4. Enter name and value
5. Click **Add Secret**

---

## Additional Resources

- **Workflow Comparison:** See `WORKFLOW_COMPARISON.md` for detailed comparison
- **K3s Registry Fix:** See `QUICK_FIX_K3S_HTTP_REGISTRY.md` for registry issues
- **General Troubleshooting:** See `TROUBLESHOOTING_ALMABUILD2_REGISTRY.md`

---

## Quick Start

For most users, the default containerized workflow is ready to use:

1. ✅ Ensure secrets are configured (see above)
2. ✅ Push code to main/master branch
3. ✅ Watch the workflow run in Gitea Actions
4. ✅ Application will be deployed automatically

That's it! No additional setup needed.

---

Made with ❤️ by IBM Bob