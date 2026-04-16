# Quick Fix: Native Workflow - Docker Not Found

## Problem
```
❌ ERROR: Docker binary not found or not executable!
```

## Quick Solution (Copy & Paste)

### Step 1: Find Your Runner Container
```bash
docker ps | grep runner
```

### Step 2: Install Docker & kubectl in Runner

**Option A: Automated (Recommended)**
```bash
# Copy setup script to container
docker cp .gitea/workflows/SETUP_NATIVE_RUNNER.sh gitea-runner:/tmp/

# Run setup script
docker exec -it gitea-runner sh /tmp/SETUP_NATIVE_RUNNER.sh
```

**Option B: Manual (Alpine Linux)**
```bash
# Enter container
docker exec -it gitea-runner sh

# Install Docker CLI
apk add --no-cache docker-cli docker-cli-buildx

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl

# Install additional tools
apk add --no-cache git bash curl openssl python3 py3-pip

# Exit container
exit
```

### Step 3: Ensure Docker Socket is Mounted

**Check if mounted:**
```bash
docker exec -it gitea-runner ls -la /var/run/docker.sock
```

**If NOT mounted, add to docker-compose.yml:**
```yaml
services:
  gitea-runner:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # ← ADD THIS LINE
      - ./data:/data
```

**Then restart:**
```bash
docker-compose down
docker-compose up -d
```

### Step 4: Verify Installation
```bash
# Test Docker
docker exec -it gitea-runner docker --version
docker exec -it gitea-runner docker ps

# Test kubectl
docker exec -it gitea-runner kubectl version --client
```

### Step 5: Test Workflow
```bash
# Push a commit to trigger the workflow
git add .
git commit -m "Test native workflow"
git push

# Check workflow in Gitea UI:
# Repository → Actions → Workflows
```

## Expected Output After Fix

```
✓ Found Docker at: /usr/bin/docker
Docker version 24.0.7, build afdd53b
✓ Docker is available and working

✓ Found kubectl at: /usr/local/bin/kubectl
Client Version: v1.29.0
✓ kubectl is available and working
```

## If Still Failing

1. **Check Docker socket permissions:**
   ```bash
   docker exec -it gitea-runner ls -la /var/run/docker.sock
   ```

2. **Verify socket is accessible:**
   ```bash
   docker exec -it gitea-runner docker ps
   ```

3. **Check runner logs:**
   ```bash
   docker logs gitea-runner
   ```

4. **Restart runner:**
   ```bash
   docker restart gitea-runner
   ```

## Alternative: Use Docker-in-Docker Workflow

If issues persist, switch to the DinD workflow (no installation needed):

```bash
# Disable native workflow
mv .gitea/workflows/build-push-deploy-native.yaml \
   .gitea/workflows/build-push-deploy-native.yaml.disabled

# The DinD workflow (build-push-deploy.yaml) will be used automatically
```

## Need More Help?

See detailed guides:
- **NATIVE_WORKFLOW_SETUP_GUIDE.md** - Complete setup instructions
- **FIX_DOCKER_IN_CONTAINER_RUNNER.md** - Alternative solutions
- **WORKFLOW_COMPARISON.md** - Compare native vs DinD workflows

---
Made with ❤️ by IBM Bob