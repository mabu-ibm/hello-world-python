# Fix: Docker Not Found in Containerized Gitea Runner

## Problem
The `build-push-deploy-native.yaml` workflow fails with "Docker binary not found" because:
- Gitea runner runs as a container
- Container doesn't have Docker installed inside it
- Native Docker/kubectl binaries are not available

## Root Cause
```
❌ ERROR: Docker binary not found or not executable!
```

The workflow expects `/usr/bin/docker` to exist, but containerized runners don't have Docker installed.

## Solutions

### ✅ Solution 1: Use Docker-in-Docker Workflow (RECOMMENDED)
Use `build-push-deploy.yaml` instead of `build-push-deploy-native.yaml`.

**Why this works:**
- Uses Docker containers to run Docker commands (Docker-in-Docker)
- Uses `bitnami/kubectl` container for Kubernetes operations
- No host dependencies required
- Works in any containerized runner environment

**How to switch:**
```bash
# In your repository, use this workflow file:
.gitea/workflows/build-push-deploy.yaml

# Delete or rename the native workflow:
mv .gitea/workflows/build-push-deploy-native.yaml \
   .gitea/workflows/build-push-deploy-native.yaml.disabled
```

### Solution 2: Mount Docker Socket (Advanced)
Configure the Gitea runner to mount the host's Docker socket.

**Runner Configuration:**
```yaml
# In runner's docker-compose.yml or run command
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
  - ./data:/data
```

**Install Docker CLI in Runner:**
```bash
# SSH to runner host
docker exec -it gitea-runner sh

# Install Docker CLI
apk add --no-cache docker-cli

# Verify
docker --version
```

### Solution 3: Use Host-Based Runner (Not Recommended)
Install runner directly on host instead of container.

**Why not recommended:**
- Less portable
- More complex setup
- Security concerns
- Harder to maintain

## Comparison: Native vs Docker-in-Docker

| Feature | Native Workflow | DinD Workflow |
|---------|----------------|---------------|
| **Docker Required** | ✅ On host | ❌ Uses containers |
| **kubectl Required** | ✅ On host | ❌ Uses containers |
| **Works in Container** | ❌ No | ✅ Yes |
| **Setup Complexity** | High | Low |
| **Portability** | Low | High |
| **Maintenance** | Complex | Simple |
| **Security** | Requires socket mount | Isolated |

## Recommended Action

**Use the Docker-in-Docker workflow:**

```bash
cd project-templates/hello-world-python

# Disable native workflow
mv .gitea/workflows/build-push-deploy-native.yaml \
   .gitea/workflows/build-push-deploy-native.yaml.disabled

# Ensure DinD workflow is active
ls -la .gitea/workflows/build-push-deploy.yaml

# Commit and push
git add .gitea/workflows/
git commit -m "Switch to Docker-in-Docker workflow for containerized runner"
git push
```

## Verification

After switching workflows, verify:

```bash
# Check workflow runs in Gitea UI
# Navigate to: Repository → Actions → Workflows

# Look for successful runs of "Build, Push and Deploy"
```

## Key Differences in Workflows

### Native Workflow (Broken in Container)
```yaml
- name: Build and Push
  run: |
    /usr/bin/docker build -t ${IMAGE_NAME}:latest .
    /usr/bin/docker push ${IMAGE_NAME}:latest
```

### DinD Workflow (Works in Container)
```yaml
- name: Build and Push
  run: |
    docker build -t ${IMAGE_NAME}:latest .
    docker push ${IMAGE_NAME}:latest
```

The DinD workflow uses the `docker` command which is available through Docker-in-Docker, while the native workflow expects `/usr/bin/docker` to exist on the host.

## Additional Notes

### When to Use Each Workflow

**Use `build-push-deploy.yaml` (DinD) when:**
- ✅ Runner is containerized
- ✅ You want portability
- ✅ You want simple setup
- ✅ You don't want to modify runner configuration

**Use `build-push-deploy-native.yaml` when:**
- ✅ Runner is installed on host (not container)
- ✅ Docker and kubectl are installed on host
- ✅ You have full control over runner environment
- ✅ You need maximum performance (no container overhead)

### Performance Considerations

- **DinD**: Slight overhead from nested containers
- **Native**: Direct host access, faster
- **Difference**: Usually negligible for most workloads

### Security Considerations

- **DinD**: More isolated, doesn't require socket mount
- **Native**: Requires Docker socket access, potential security risk

## Troubleshooting

### If DinD workflow also fails:

1. **Check Docker socket access:**
   ```bash
   docker exec -it gitea-runner ls -la /var/run/docker.sock
   ```

2. **Verify runner can run Docker:**
   ```bash
   docker exec -it gitea-runner docker ps
   ```

3. **Check runner logs:**
   ```bash
   docker logs gitea-runner
   ```

### If you must use native workflow:

1. **Install Docker in runner container:**
   ```bash
   docker exec -it gitea-runner sh
   apk add --no-cache docker-cli
   ```

2. **Mount Docker socket:**
   ```yaml
   volumes:
     - /var/run/docker.sock:/var/run/docker.sock
   ```

3. **Restart runner:**
   ```bash
   docker restart gitea-runner
   ```

## Conclusion

**The simplest and most reliable solution is to use `build-push-deploy.yaml` (Docker-in-Docker workflow).** It's designed specifically for containerized runner environments and requires no additional configuration.

---
Made with ❤️ by IBM Bob