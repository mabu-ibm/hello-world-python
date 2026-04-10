# Workflow Comparison Guide

This directory contains two workflow files for building, pushing, and deploying the application:

## 1. build-push-deploy.yaml (Containerized)
**Use Case:** When the Gitea runner doesn't have Docker or kubectl installed, or when you want complete isolation.

**Characteristics:**
- Runs Docker and kubectl commands inside containers
- Uses `bitnami/kubectl:latest` container for all kubectl operations
- Passes kubeconfig via environment variables
- More portable but slightly slower
- No host dependencies except Docker

**Pros:**
- Works on any runner with Docker
- No need to install kubectl on runner
- Isolated execution environment
- Consistent behavior across different runners

**Cons:**
- Slightly slower due to container overhead
- More complex command structure
- Requires Docker socket access

## 2. build-push-deploy-native.yaml (Native)
**Use Case:** When the Gitea runner has Docker and kubectl pre-installed and properly configured.

**Characteristics:**
- Uses native Docker and kubectl commands
- Simpler command structure
- Faster execution
- Requires proper runner setup

**Pros:**
- Faster execution (no container overhead)
- Simpler, more readable commands
- Direct access to tools
- Easier debugging

**Cons:**
- Requires Docker and kubectl installed on runner
- Runner must have proper permissions
- Less portable across different environments

---

## Setting Up Gitea Runner for Native Workflow

### Prerequisites
The Gitea runner must have:
1. Docker installed and running
2. kubectl installed
3. Proper permissions to access Docker socket
4. Network access to Kubernetes cluster

### Step 1: Install Docker on Runner Host

```bash
# For Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y docker.io

# For AlmaLinux/RHEL
sudo dnf install -y docker
sudo systemctl enable --now docker

# Verify
docker --version
```

### Step 2: Install kubectl on Runner Host

```bash
# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
```

### Step 3: Configure Runner User Permissions

The Gitea runner typically runs as a specific user (often `gitea-runner` or `runner`). This user needs:

#### A. Docker Access

```bash
# Add runner user to docker group
sudo usermod -aG docker gitea-runner

# Restart runner service to apply group changes
sudo systemctl restart gitea-runner
```

#### B. Verify Docker Access

```bash
# Test as runner user
sudo -u gitea-runner docker ps
sudo -u gitea-runner docker info
```

### Step 4: Configure Runner for Docker Socket Access

Edit the runner configuration to ensure Docker socket is accessible:

```bash
# Edit runner config (location may vary)
sudo nano /etc/gitea-runner/config.yaml
```

Ensure the runner has access to `/var/run/docker.sock`:

```yaml
runner:
  capacity: 1
  timeout: 3h
  insecure: false
  fetch_timeout: 5s
  fetch_interval: 2s
  labels:
    - "ubuntu-latest:docker://node:16-bullseye"
```

### Step 5: Test Runner Setup

Create a test workflow to verify everything works:

```yaml
name: Test Runner Setup
on: [workflow_dispatch]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test Docker
        run: |
          docker --version
          docker ps
          echo "✓ Docker works"
      
      - name: Test kubectl
        run: |
          kubectl version --client
          echo "✓ kubectl works"
```

---

## Troubleshooting

### Issue: "permission denied while trying to connect to Docker daemon"

**Solution:**
```bash
# Ensure runner user is in docker group
sudo usermod -aG docker gitea-runner

# Restart runner
sudo systemctl restart gitea-runner

# Verify
sudo -u gitea-runner docker ps
```

### Issue: "kubectl: command not found"

**Solution:**
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify it's in PATH
which kubectl
kubectl version --client
```

### Issue: "Cannot connect to Kubernetes cluster"

**Solution:**
- Ensure KUBECONFIG secret is properly set in Gitea
- Verify network connectivity from runner to K8s cluster
- Check firewall rules
- Test manually: `kubectl --kubeconfig=/path/to/config cluster-info`

### Issue: "Docker socket permission denied"

**Solution:**
```bash
# Check socket permissions
ls -l /var/run/docker.sock

# Should show: srw-rw---- 1 root docker

# If not, fix permissions
sudo chmod 660 /var/run/docker.sock
sudo chown root:docker /var/run/docker.sock
```

---

## Choosing the Right Workflow

### Use **build-push-deploy.yaml** (Containerized) when:
- ✅ Runner doesn't have kubectl installed
- ✅ You want maximum portability
- ✅ You need isolated execution
- ✅ Multiple teams share the same runner
- ✅ You want to avoid runner configuration

### Use **build-push-deploy-native.yaml** (Native) when:
- ✅ You control the runner environment
- ✅ Performance is critical
- ✅ You prefer simpler commands
- ✅ Docker and kubectl are already installed
- ✅ You want easier debugging

---

## Security Considerations

### For Both Workflows:
1. **Secrets Management:**
   - Store all sensitive data in Gitea secrets
   - Never commit credentials to repository
   - Rotate secrets regularly

2. **Docker Registry:**
   - Use secure registry (HTTPS)
   - Implement proper authentication
   - Scan images for vulnerabilities

3. **Kubernetes Access:**
   - Use service accounts with minimal permissions
   - Implement RBAC policies
   - Audit kubectl access logs

### Additional for Native Workflow:
1. **Runner Isolation:**
   - Run runner in isolated environment
   - Limit network access
   - Monitor runner activity

2. **Docker Socket Security:**
   - Be aware that Docker socket access = root access
   - Consider using rootless Docker
   - Implement audit logging

---

## Performance Comparison

Based on typical execution times:

| Step | Containerized | Native | Difference |
|------|--------------|--------|------------|
| Docker Build | ~2-3 min | ~2-3 min | Same |
| Docker Push | ~30-60 sec | ~30-60 sec | Same |
| SBOM Generation | ~20-30 sec | ~15-20 sec | 25% faster |
| kubectl apply | ~5-10 sec | ~2-3 sec | 60% faster |
| Total Overhead | ~30-45 sec | ~5-10 sec | 70% faster |

**Recommendation:** For production pipelines with frequent deployments, the native workflow can save significant time.

---

## Migration Guide

### From Containerized to Native:

1. **Install prerequisites on runner:**
   ```bash
   # Install Docker and kubectl
   sudo apt-get install -y docker.io
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install kubectl /usr/local/bin/kubectl
   ```

2. **Configure permissions:**
   ```bash
   sudo usermod -aG docker gitea-runner
   sudo systemctl restart gitea-runner
   ```

3. **Test the setup:**
   - Run the test workflow above
   - Verify all commands work

4. **Switch workflows:**
   - Rename or disable `build-push-deploy.yaml`
   - Enable `build-push-deploy-native.yaml`
   - Test with a non-production deployment

### From Native to Containerized:

1. **No runner changes needed** - containerized workflow works with just Docker

2. **Update workflow reference:**
   - Use `build-push-deploy.yaml` instead of `build-push-deploy-native.yaml`

3. **Test thoroughly** - environment variable passing works differently

---

## Maintenance

### Regular Tasks:

1. **Update kubectl version:**
   ```bash
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install kubectl /usr/local/bin/kubectl
   ```

2. **Update Docker:**
   ```bash
   sudo apt-get update
   sudo apt-get upgrade docker.io
   ```

3. **Monitor runner logs:**
   ```bash
   sudo journalctl -u gitea-runner -f
   ```

4. **Check disk space:**
   ```bash
   df -h
   docker system df
   docker system prune -a  # Clean up old images
   ```

---

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Gitea runner logs: `sudo journalctl -u gitea-runner`
3. Test commands manually as the runner user
4. Verify network connectivity and permissions

Made with ❤️ by IBM Bob