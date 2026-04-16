# Gitea Secrets - Complete Examples

## Overview
This document provides complete examples for all 5 required Gitea secrets used in the CI/CD workflow.

## Required Secrets

### 1. GIT_REGISTRY
**Purpose**: Docker registry URL where images will be pushed

**Example Values:**
```
# Local registry on almabuild2
almabuild2.lab.allwaysbeginner.com:5000

# Docker Hub
docker.io

# GitHub Container Registry
ghcr.io

# GitLab Container Registry
registry.gitlab.com
```

**How to Set in Gitea UI:**
1. Go to your repository
2. Click **Settings** → **Secrets** → **Actions**
3. Click **Add Secret**
4. Name: `GIT_REGISTRY`
5. Value: `almabuild2.lab.allwaysbeginner.com:5000`
6. Click **Add Secret**

---

### 2. GIT_USERNAME
**Purpose**: Username for Docker registry authentication

**Example Values:**
```
# Local registry
admin

# Docker Hub
your-dockerhub-username

# GitHub Container Registry
your-github-username

# GitLab Container Registry
your-gitlab-username
```

**How to Set in Gitea UI:**
1. Repository → **Settings** → **Secrets** → **Actions**
2. Click **Add Secret**
3. Name: `GIT_USERNAME`
4. Value: `admin`
5. Click **Add Secret**

---

### 3. GIT_TOKEN
**Purpose**: Password/token for Docker registry authentication

**Example Values:**
```
# Local registry password
your-registry-password

# Docker Hub (use access token, not password)
dckr_pat_xxxxxxxxxxxxxxxxxxxxx

# GitHub Personal Access Token (with write:packages scope)
ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# GitLab Personal Access Token (with write_registry scope)
glpat-xxxxxxxxxxxxxxxxxxxx
```

**How to Set in Gitea UI:**
1. Repository → **Settings** → **Secrets** → **Actions**
2. Click **Add Secret**
3. Name: `GIT_TOKEN`
4. Value: `your-registry-password`
5. Click **Add Secret**

**Security Note:** Never use your actual password. Use access tokens when available.

---

### 4. KUBECONFIG
**Purpose**: Kubernetes configuration for kubectl access to deploy applications

**How to Get Your KUBECONFIG:**
```bash
# On your K3s server (almak3s)
sudo cat /etc/rancher/k3s/k3s.yaml
```

**Example Value (copy entire output):**
```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTi...VERY_LONG_BASE64...FURS0tLS0tCg==
    server: https://192.168.178.87:6443
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    client-certificate-data: LS0tLS1CRUdJTi...VERY_LONG_BASE64...FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJTi...VERY_LONG_BASE64...FURS0tLS0tCg==
```

**How to Set in Gitea UI:**
1. Repository → **Settings** → **Secrets** → **Actions**
2. Click **Add Secret**
3. Name: `KUBECONFIG`
4. Value: Paste the **entire** kubeconfig content (including all base64 data)
5. Click **Add Secret**

**Important Notes:**
- Copy the ENTIRE kubeconfig file content
- Include all the long base64-encoded certificate data
- Don't modify or truncate any part of it
- The base64 strings are very long (thousands of characters) - this is normal

---

### 5. INGRESS_HOST
**Purpose**: The hostname/domain where your application will be accessible

**Example Values:**
```
# Local lab domain
hello-world-python.lab.allwaysbeginner.com

# Production domain
myapp.example.com

# Subdomain
api.mycompany.com
```

**How to Set in Gitea UI:**
1. Repository → **Settings** → **Secrets** → **Actions**
2. Click **Add Secret**
3. Name: `INGRESS_HOST`
4. Value: `hello-world-python.lab.allwaysbeginner.com`
5. Click **Add Secret**

**Important:** This hostname must:
- Resolve to your K3s cluster IP (via DNS or /etc/hosts)
- Match the ingress configuration in your deployment

---

## Complete Setup Example

Here's a complete example for a local lab setup:

| Secret Name | Example Value |
|-------------|---------------|
| `GIT_REGISTRY` | `almabuild2.lab.allwaysbeginner.com:5000` |
| `GIT_USERNAME` | `admin` |
| `GIT_TOKEN` | `myregistrypassword123` |
| `KUBECONFIG` | `apiVersion: v1\nclusters:\n- cluster:...` (full config) |
| `INGRESS_HOST` | `hello-world-python.lab.allwaysbeginner.com` |

---

## How to Get KUBECONFIG (Detailed Steps)

### Method 1: From K3s Server
```bash
# SSH to your K3s server
ssh user@almak3s.lab.allwaysbeginner.com

# Get the kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml

# Copy the entire output (Ctrl+A, Ctrl+C)
```

### Method 2: From Local Machine (if kubectl is configured)
```bash
# Get your current kubeconfig
cat ~/.kube/config

# Or get it in base64 (for easier copying)
cat ~/.kube/config | base64
```

### Method 3: Export from K3s
```bash
# On K3s server, export to a file
sudo cp /etc/rancher/k3s/k3s.yaml ~/kubeconfig.yaml
sudo chown $USER:$USER ~/kubeconfig.yaml

# Edit the server IP if needed
sed -i 's/127.0.0.1/192.168.178.87/g' ~/kubeconfig.yaml

# Display the content
cat ~/kubeconfig.yaml
```

---

## Verification

After setting all secrets, verify they are configured:

### In Gitea UI:
1. Go to Repository → **Settings** → **Secrets** → **Actions**
2. You should see all 5 secrets listed:
   - ✅ GIT_REGISTRY
   - ✅ GIT_USERNAME
   - ✅ GIT_TOKEN
   - ✅ KUBECONFIG
   - ✅ INGRESS_HOST

### Test the Workflow:
```bash
# Make a small change and push
echo "# Test" >> README.md
git add README.md
git commit -m "Test workflow with secrets"
git push

# Check workflow in Gitea UI
# Repository → Actions → Should see workflow running
```

---

## Troubleshooting

### Secret Not Found Error
```
❌ Missing secret: GIT_REGISTRY
```
**Solution:** The secret name must match exactly (case-sensitive). Check spelling.

### KUBECONFIG Invalid
```
error: error loading config file "/github/workspace/.kube/config": yaml: line X: did not find expected key
```
**Solution:** 
- Ensure you copied the ENTIRE kubeconfig
- Check for any truncation or missing lines
- Verify the base64 data is complete

### Registry Authentication Failed
```
Error response from daemon: Get "https://almabuild2.lab.allwaysbeginner.com:5000/v2/": unauthorized
```
**Solution:**
- Verify GIT_USERNAME and GIT_TOKEN are correct
- Test login manually: `docker login almabuild2.lab.allwaysbeginner.com:5000`

### Ingress Host Not Resolving
```
curl: (6) Could not resolve host: hello-world-python.lab.allwaysbeginner.com
```
**Solution:**
- Add to /etc/hosts: `192.168.178.87 hello-world-python.lab.allwaysbeginner.com`
- Or configure DNS to resolve the hostname

---

## Security Best Practices

1. **Never commit secrets to Git**
   - Use Gitea Secrets feature
   - Add `.env` files to `.gitignore`

2. **Use tokens instead of passwords**
   - Docker Hub: Create access token
   - GitHub: Create PAT with minimal scopes
   - GitLab: Create deploy token

3. **Rotate secrets regularly**
   - Change passwords/tokens periodically
   - Update secrets in Gitea after rotation

4. **Limit secret access**
   - Only add secrets to repositories that need them
   - Use repository-specific secrets, not organization-wide

5. **Audit secret usage**
   - Review workflow logs for secret leaks
   - Check Actions logs don't print secrets

---

## Quick Reference Card

```bash
# Get KUBECONFIG
ssh almak3s "sudo cat /etc/rancher/k3s/k3s.yaml"

# Test registry login
docker login almabuild2.lab.allwaysbeginner.com:5000 -u admin -p yourpassword

# Test kubectl access
export KUBECONFIG=/path/to/kubeconfig.yaml
kubectl get nodes

# Test ingress host resolution
ping hello-world-python.lab.allwaysbeginner.com
curl http://hello-world-python.lab.allwaysbeginner.com
```

---

Made with ❤️ by IBM Bob