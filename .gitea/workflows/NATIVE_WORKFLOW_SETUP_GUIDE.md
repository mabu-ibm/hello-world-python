# Native Workflow Setup Guide

## Overview
This guide helps you set up the **native workflow** (`build-push-deploy-native.yaml`) to use locally installed Docker and kubectl in your Gitea runner container.

## Problem
The native workflow fails with:
```
❌ ERROR: Docker binary not found or not executable!
```

This happens because the Gitea runner runs as a container and doesn't have Docker/kubectl installed by default.

## Solution: Install Docker & kubectl in Runner Container

### Quick Setup (Automated)

**Step 1: Copy setup script to runner container**
```bash
# Find your runner container name
docker ps | grep runner

# Copy the setup script
docker cp .gitea/workflows/SETUP_NATIVE_RUNNER.sh <runner-container-name>:/tmp/

# Example:
docker cp .gitea/workflows/SETUP_NATIVE_RUNNER.sh gitea-runner:/tmp/
```

**Step 2: Execute setup script inside container**
```bash
# Run the setup script
docker exec -it <runner-container-name> sh /tmp/SETUP_NATIVE_RUNNER.sh

# Example:
docker exec -it gitea-runner sh /tmp/SETUP_NATIVE_RUNNER.sh
```

**Step 3: Verify installation**
```bash
# Check Docker
docker exec -it <runner-container-name> docker --version

# Check kubectl
docker exec -it <runner-container-name> kubectl version --client

# Test Docker access
docker exec -it <runner-container-name> docker ps
```

### Manual Setup (Step-by-Step)

If you prefer manual installation or the automated script fails:

#### 1. Access the Runner Container
```bash
# Find container name
docker ps | grep runner

# Enter the container
docker exec -it <runner-container-name> sh
```

#### 2. Install Docker CLI

**For Alpine Linux (most common):**
```bash
apk add --no-cache docker-cli docker-cli-buildx
```

**For Debian/Ubuntu:**
```bash
apt-get update
apt-get install -y docker.io
```

**For RHEL/CentOS:**
```bash
yum install -y docker
```

#### 3. Verify Docker Socket Access

The runner container MUST have the Docker socket mounted:

```bash
# Check if socket exists
ls -la /var/run/docker.sock

# Test Docker access
docker ps
```

If the socket is not accessible, you need to mount it (see next section).

#### 4. Install kubectl

```bash
# Download latest kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Make executable and move to PATH
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
```

#### 5. Install Additional Tools

```bash
# For Alpine
apk add --no-cache git bash curl openssl python3 py3-pip

# For Debian/Ubuntu
apt-get install -y git curl openssl python3 python3-pip

# For RHEL/CentOS
yum install -y git curl openssl python3 python3-pip
```

## Runner Configuration

### Docker Socket Mount (REQUIRED)

The runner container MUST have access to the host's Docker socket.

#### Option 1: Docker Compose

Edit your `docker-compose.yml`:

```yaml
services:
  gitea-runner:
    image: gitea/act_runner:latest
    container_name: gitea-runner
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # ← ADD THIS
      - ./data:/data
    environment:
      - GITEA_INSTANCE_URL=http://almabuild2:3000
      - GITEA_RUNNER_REGISTRATION_TOKEN=your-token
    restart: unless-stopped
```

Then restart:
```bash
docker-compose down
docker-compose up -d
```

#### Option 2: Docker Run Command

If you started the runner with `docker run`, add the volume mount:

```bash
docker run -d \
  --name gitea-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/data:/data \
  -e GITEA_INSTANCE_URL=http://almabuild2:3000 \
  -e GITEA_RUNNER_REGISTRATION_TOKEN=your-token \
  --restart unless-stopped \
  gitea/act_runner:latest
```

### Verify Socket Mount

```bash
# Check if socket is mounted
docker exec -it gitea-runner ls -la /var/run/docker.sock

# Test Docker access
docker exec -it gitea-runner docker ps
```

## Workflow Configuration

### Using the Native Workflow

The native workflow (`build-push-deploy-native.yaml`) uses absolute paths to binaries:

```yaml
- name: Build and Push
  run: |
    /usr/bin/docker build -t ${IMAGE_NAME}:latest .
    /usr/bin/docker push ${IMAGE_NAME}:latest
```

### Path Locations

After installation, binaries are located at:
- **Docker**: `/usr/bin/docker` or `/usr/local/bin/docker`
- **kubectl**: `/usr/local/bin/kubectl` or `/usr/bin/kubectl`
- **Python**: `/usr/bin/python3`
- **Git**: `/usr/bin/git`

The workflow checks multiple locations automatically.

## Troubleshooting

### Issue 1: Docker Socket Permission Denied

**Error:**
```
permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
```bash
# Check socket permissions
docker exec -it gitea-runner ls -la /var/run/docker.sock

# Add runner user to docker group (if needed)
docker exec -it gitea-runner addgroup runner docker

# Or run runner as root (less secure)
```

### Issue 2: Docker Not Found After Installation

**Error:**
```
docker: command not found
```

**Solution:**
```bash
# Check installation
docker exec -it gitea-runner which docker

# Check PATH
docker exec -it gitea-runner echo $PATH

# Create symlink if needed
docker exec -it gitea-runner ln -s /usr/bin/docker /usr/local/bin/docker
```

### Issue 3: kubectl Cannot Connect to Cluster

**Error:**
```
The connection to the server localhost:8080 was refused
```

**Solution:**
- Verify KUBECONFIG secret is set in Gitea
- Check kubeconfig format (base64 or plain text)
- Test kubeconfig manually:
  ```bash
  docker exec -it gitea-runner kubectl --kubeconfig=/path/to/config get nodes
  ```

### Issue 4: Workflow Still Fails After Setup

**Checklist:**
1. ✅ Docker CLI installed in container
2. ✅ Docker socket mounted at `/var/run/docker.sock`
3. ✅ Docker socket accessible (`docker ps` works)
4. ✅ kubectl installed in container
5. ✅ KUBECONFIG secret configured in Gitea
6. ✅ Runner container restarted after changes

**Debug commands:**
```bash
# Check Docker
docker exec -it gitea-runner docker --version
docker exec -it gitea-runner docker ps

# Check kubectl
docker exec -it gitea-runner kubectl version --client

# Check file permissions
docker exec -it gitea-runner ls -la /usr/bin/docker
docker exec -it gitea-runner ls -la /usr/local/bin/kubectl

# Check PATH
docker exec -it gitea-runner echo $PATH
```

## Verification

After setup, verify everything works:

```bash
# 1. Check Docker
docker exec -it gitea-runner docker --version
docker exec -it gitea-runner docker ps

# 2. Check kubectl
docker exec -it gitea-runner kubectl version --client

# 3. Check Python
docker exec -it gitea-runner python3 --version

# 4. Check Git
docker exec -it gitea-runner git --version

# 5. Test workflow
# Push a commit to trigger the workflow and check Gitea Actions
```

## Alternative: Use Docker-in-Docker Workflow

If you encounter persistent issues with the native workflow, consider using the Docker-in-Docker workflow (`build-push-deploy.yaml`) instead:

**Advantages:**
- No installation required
- Works out of the box
- More portable
- Easier to maintain

**Disadvantages:**
- Slight performance overhead
- Nested container complexity

See `FIX_DOCKER_IN_CONTAINER_RUNNER.md` for details.

## Summary

To use the native workflow with locally installed Docker and kubectl:

1. **Install Docker CLI** in the runner container
2. **Mount Docker socket** from host to container
3. **Install kubectl** in the runner container
4. **Verify** all tools are accessible
5. **Restart** runner container
6. **Test** workflow execution

The native workflow will then use the locally installed tools instead of containerized versions.

---
Made with ❤️ by IBM Bob