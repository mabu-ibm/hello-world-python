# Secure CI/CD Pipeline

Automated build, security scanning, and deployment pipeline with enterprise-grade security.

## 🔒 Pipeline Overview

```
Developer Push → Gitea
    ↓
Job 1: Test Application
    ↓
Job 2: Build Secure Image + Security Scan
    ↓
Job 3: Deploy with Security Hardening + Verify
    ↓
Application Running Securely in K3s
```

## 🎯 What Happens Automatically

### When You Push Code

1. **Automatic Testing** - Python application tests run
2. **Secure Image Build** - Uses `Dockerfile.secure` (hardened)
3. **Security Scanning** - Trivy scans for vulnerabilities
4. **Secure Deployment** - Deploys with all security features
5. **Security Verification** - Confirms security settings
6. **Health Checks** - Verifies application is running

**Total Time:** 3-5 minutes  
**Manual Steps:** Zero (fully automated)

## 📋 Pipeline Jobs

### Job 1: Test Application

**Purpose:** Validate code before building

**Steps:**
- Checkout code
- Install Python dependencies
- Run application tests
- Verify imports work

**Container:** `nikolaik/python-nodejs:python3.11-nodejs20`

**Duration:** ~30 seconds

### Job 2: Build Secure Image + Security Scan

**Purpose:** Create hardened container image

**Steps:**
1. **Install Docker CLI** - For building images
2. **Checkout code** - Get latest code
3. **Setup Docker Buildx** - Configure for insecure registry
4. **Login to Registry** - Authenticate with Gitea
5. **Build Secure Image** - Uses `Dockerfile.secure`
   - Multi-stage build
   - Hardened base image
   - Non-root user (UID 1000)
   - Security updates installed
   - Minimal attack surface
6. **Security Scan** - Trivy vulnerability scanning
   - Scans for HIGH and CRITICAL vulnerabilities
   - Reports findings
   - Continues even if vulnerabilities found (exit-code 0)
7. **Tag Images** - Tags with `latest` and commit SHA

**Security Features in Image:**
- ✅ Non-root user (UID 1000)
- ✅ Read-only app directory
- ✅ Security updates applied
- ✅ Minimal base image
- ✅ No shell (prevents attacks)
- ✅ dumb-init for signal handling

**Duration:** ~2-3 minutes

### Job 3: Deploy with Security Hardening

**Purpose:** Deploy to K3s with full security

**Steps:**
1. **Install kubectl** - K8s command-line tool
2. **Setup kubeconfig** - From Gitea secret
3. **Verify kubectl access** - Test K3s connection
4. **Deploy Secure Manifests**:
   - `deployment-secure.yaml` - Deployment with security contexts
   - `network-policy.yaml` - Network isolation
5. **Wait for rollout** - Ensure deployment succeeds
6. **Get deployment info** - Show pods, services
7. **Verify health** - Wait for pods to be ready
8. **Security verification** - Confirm all security features

**Security Features in Deployment:**
- ✅ Pod security context (runAsNonRoot, runAsUser: 1000)
- ✅ Container security context (readOnlyRootFilesystem)
- ✅ Dropped ALL capabilities
- ✅ Service account (dedicated)
- ✅ Network policy (ingress/egress rules)
- ✅ Resource limits (CPU, memory, storage)
- ✅ Health probes (liveness, readiness, startup)
- ✅ ConfigMap and Secrets
- ✅ Pod anti-affinity

**Duration:** ~1-2 minutes

## 🔐 Security Features

### Container Security (Image)

| Feature | Status | Description |
|---------|--------|-------------|
| Non-root user | ✅ | Runs as UID 1000 (appuser) |
| Hardened base | ✅ | python:3.11-slim with security updates |
| Read-only app | ✅ | Application directory is read-only |
| Minimal packages | ✅ | Only essential packages installed |
| Security updates | ✅ | Latest security patches applied |
| dumb-init | ✅ | Proper signal handling |
| Health checks | ✅ | Built-in health endpoint |

### Kubernetes Security (Deployment)

| Feature | Status | Description |
|---------|--------|-------------|
| Security contexts | ✅ | Pod and container level |
| Read-only filesystem | ✅ | Root filesystem is read-only |
| Dropped capabilities | ✅ | ALL capabilities dropped |
| Service account | ✅ | Dedicated account, no auto-mount |
| Network policy | ✅ | Ingress and egress rules |
| Resource limits | ✅ | CPU, memory, storage limits |
| Health probes | ✅ | Liveness, readiness, startup |
| Seccomp profile | ✅ | RuntimeDefault profile |

### Pipeline Security

| Feature | Status | Description |
|---------|--------|-------------|
| Vulnerability scanning | ✅ | Trivy scans for CVEs |
| Secure registry | ✅ | Private Gitea registry |
| Secret management | ✅ | Credentials in Gitea secrets |
| Security verification | ✅ | Automated security checks |
| Audit trail | ✅ | All actions logged |

## 📊 Security Verification

After deployment, the pipeline automatically verifies:

1. **Security Contexts**
   - Pod runs as non-root ✓
   - Read-only root filesystem ✓

2. **Service Account**
   - Dedicated service account ✓
   - No auto-mount token ✓

3. **Network Policy**
   - Network isolation applied ✓
   - Ingress/egress rules active ✓

4. **Resource Limits**
   - CPU limits configured ✓
   - Memory limits configured ✓
   - Storage limits configured ✓

## 🚀 How to Use

### Initial Setup (One Time)

1. **Create Gitea Secrets** (in repository settings):
   ```
   REGISTRY_TOKEN - Personal Access Token for registry
   KUBECONFIG - Base64-encoded kubeconfig for K3s
   ```

2. **Ensure Files Exist**:
   - `Dockerfile.secure` - Hardened Dockerfile
   - `k8s/deployment-secure.yaml` - Secure deployment
   - `k8s/network-policy.yaml` - Network policy
   - `.gitea/workflows/build-push-deploy.yaml` - This pipeline

3. **Create Registry Secret on K3s**:
   ```bash
   kubectl create secret docker-registry gitea-registry \
     --docker-server=almabuild.lab.allwaysbeginner.com:3000 \
     --docker-username=YOUR_USERNAME \
     --docker-password=YOUR_PASSWORD
   ```

### Daily Usage

**Just push your code!**

```bash
# Make changes
nano app.py

# Commit and push
git add .
git commit -m "Update feature"
git push

# Pipeline runs automatically!
# Watch in Gitea → Repository → Actions tab
```

### What You'll See

1. **Actions Tab** - Three jobs running
2. **Test Job** - Green checkmark when tests pass
3. **Build Job** - Image built and scanned
4. **Deploy Job** - Application deployed securely
5. **Security Verification** - All checks pass

## 🔍 Monitoring the Pipeline

### View Pipeline Status

```
Gitea → Repository → Actions → Latest Run
```

### Check Logs

Click on any job to see detailed logs:
- Test output
- Build progress
- Security scan results
- Deployment status
- Security verification

### Verify Deployment

```bash
# On almak3s or almabuild (with kubectl)
kubectl get pods -l app=hello-world-python
kubectl get service hello-world-python
kubectl describe pod -l app=hello-world-python
```

## 🐛 Troubleshooting

### Pipeline Fails at Test Job

**Cause:** Application code has errors

**Solution:**
```bash
# Test locally
python app.py
# Fix errors and push again
```

### Pipeline Fails at Build Job

**Cause:** Docker build errors or registry issues

**Solution:**
```bash
# Test build locally
docker build -f Dockerfile.secure -t test .
# Check registry credentials in Gitea secrets
```

### Pipeline Fails at Deploy Job

**Cause:** kubectl can't connect or manifests invalid

**Solution:**
```bash
# Verify KUBECONFIG secret is correct
# Test manifests locally
kubectl apply -f k8s/deployment-secure.yaml --dry-run=client
```

### Security Scan Shows Vulnerabilities

**Cause:** Base image or dependencies have CVEs

**Solution:**
```bash
# Update base image in Dockerfile.secure
FROM python:3.11-slim  # Use latest version

# Update dependencies
pip install --upgrade package-name
```

### Deployment Succeeds but Pods Crash

**Cause:** Security constraints too restrictive

**Solution:**
```bash
# Check pod logs
kubectl logs -l app=hello-world-python

# Common issues:
# - Missing writable volumes (/tmp, /home/appuser/.cache)
# - Application tries to write to read-only filesystem
# - Resource limits too low
```

## 📈 Pipeline Metrics

### Typical Run Times

- **Test Job:** 30 seconds
- **Build Job:** 2-3 minutes
- **Deploy Job:** 1-2 minutes
- **Total:** 3-5 minutes

### Resource Usage

- **Build:** ~2GB RAM, 1 CPU
- **Deploy:** ~256MB RAM per pod
- **Storage:** ~200MB per image

## 🎯 Best Practices

### Code Changes

1. **Test locally first** - Run tests before pushing
2. **Small commits** - Easier to debug if pipeline fails
3. **Meaningful messages** - Helps track changes
4. **Review logs** - Check pipeline output

### Security

1. **Keep secrets secure** - Never commit credentials
2. **Update regularly** - Keep base images current
3. **Review scan results** - Address vulnerabilities
4. **Monitor deployments** - Check security verification

### Performance

1. **Cache dependencies** - Faster builds
2. **Optimize images** - Smaller is better
3. **Resource limits** - Right-size for your app
4. **Health probes** - Tune for your app

## 🔄 Pipeline Workflow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Developer Push                        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Job 1: Test                                              │
│  - Checkout code                                         │
│  - Install dependencies                                  │
│  - Run tests                                             │
│  Duration: ~30s                                          │
└────────────────────┬────────────────────────────────────┘
                     │ ✓ Tests Pass
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Job 2: Build Secure Image + Scan                        │
│  - Setup Docker                                          │
│  - Build with Dockerfile.secure                          │
│  - Push to registry (latest + SHA)                      │
│  - Scan with Trivy                                       │
│  Duration: ~2-3min                                       │
└────────────────────┬────────────────────────────────────┘
                     │ ✓ Image Built & Scanned
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Job 3: Deploy Secure + Verify                           │
│  - Install kubectl                                       │
│  - Setup kubeconfig                                      │
│  - Apply deployment-secure.yaml                          │
│  - Apply network-policy.yaml                             │
│  - Wait for rollout                                      │
│  - Verify security settings                              │
│  Duration: ~1-2min                                       │
└────────────────────┬────────────────────────────────────┘
                     │ ✓ Deployed & Verified
                     ▼
┌─────────────────────────────────────────────────────────┐
│          Application Running Securely in K3s             │
│  - 2 pods with full security                             │
│  - Network isolation active                              │
│  - Health checks passing                                 │
└─────────────────────────────────────────────────────────┘
```

## 📚 Related Documentation

- **Security Guide:** [SECURITY_SETUP.md](SECURITY_SETUP.md)
- **Deployment Guide:** [DEPLOY_ON_ALMAK3S.md](DEPLOY_ON_ALMAK3S.md)
- **Full Security:** [../../docs/SECURITY_HARDENING_GUIDE.md](../../docs/SECURITY_HARDENING_GUIDE.md)
- **Infrastructure:** [../../docs/COMPLETE_INFRASTRUCTURE_GUIDE.md](../../docs/COMPLETE_INFRASTRUCTURE_GUIDE.md)

---

**Pipeline Status:** ✅ Fully Automated  
**Security Level:** 🔒🔒🔒🔒🔒 Enterprise-Grade  
**Maintenance:** Low (automated)

---

**Created with IBM Bob AI** 🤖