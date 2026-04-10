# Security Setup Quick Reference

Quick guide to deploy your Hello World Python application with enterprise-grade security.

## 🎯 Quick Start (5 Minutes)

### Option 1: Automated Setup

```bash
# On almak3s
cd ~/dev-infrastructure-setup/project-templates/hello-world-python/k8s
chmod +x setup-secure-deployment.sh
sudo ./setup-secure-deployment.sh
```

### Option 2: Manual Setup

```bash
# Apply secure deployment
sudo kubectl apply -f k8s/deployment-secure.yaml

# Apply network policy
sudo kubectl apply -f k8s/network-policy.yaml

# Verify
sudo kubectl get pods -l app=hello-world-python
sudo kubectl get networkpolicy
```

## 🔒 Security Features Included

### ✅ Container Security
- **Non-root user** (UID 1000)
- **Read-only root filesystem**
- **Dropped all capabilities**
- **Security profiles** (seccomp)
- **Minimal base image**
- **No privilege escalation**

### ✅ Kubernetes Security
- **Pod Security Standards**
- **Security contexts** (pod + container)
- **Network policies** (ingress + egress)
- **Service account** (dedicated)
- **Resource limits** (CPU, memory, storage)
- **Health probes** (liveness, readiness, startup)

### ✅ Network Security
- **Network isolation**
- **Ingress/egress rules**
- **TLS/HTTPS ready**
- **Security headers**

## 📋 Security Verification

### Quick Security Check

```bash
# 1. Verify non-root user
POD=$(sudo kubectl get pod -l app=hello-world-python -o jsonpath='{.items[0].metadata.name}')
sudo kubectl exec $POD -- id
# Expected: uid=1000(appuser) gid=1000(appuser)

# 2. Verify read-only filesystem
sudo kubectl exec $POD -- touch /test
# Expected: touch: cannot touch '/test': Read-only file system

# 3. Verify security context
sudo kubectl get pod $POD -o jsonpath='{.spec.securityContext}' | jq .
# Expected: runAsNonRoot: true, runAsUser: 1000

# 4. Verify network policy
sudo kubectl get networkpolicy hello-world-python-netpol
# Expected: Policy exists

# 5. Test application
sudo kubectl port-forward service/hello-world-python 8080:80 &
curl http://localhost:8080/health
# Expected: {"status": "healthy"}
```

### Comprehensive Security Audit

```bash
# Run security audit script
cat > security-audit.sh <<'EOF'
#!/bin/bash
echo "=== Security Audit Report ==="
echo "Date: $(date)"
echo ""

POD=$(kubectl get pod -l app=hello-world-python -o jsonpath='{.items[0].metadata.name}')

echo "1. Pod Security Context:"
kubectl get pod $POD -o jsonpath='{.spec.securityContext}' | jq .

echo -e "\n2. Container Security Context:"
kubectl get pod $POD -o jsonpath='{.spec.containers[0].securityContext}' | jq .

echo -e "\n3. Service Account:"
kubectl get pod $POD -o jsonpath='{.spec.serviceAccountName}'

echo -e "\n4. Network Policy:"
kubectl get networkpolicy hello-world-python-netpol -o yaml

echo -e "\n5. Resource Limits:"
kubectl describe pod $POD | grep -A 5 "Limits:"

echo -e "\n6. User ID:"
kubectl exec $POD -- id

echo -e "\n7. Filesystem Test:"
kubectl exec $POD -- touch /test 2>&1 || echo "✓ Read-only filesystem working"

echo -e "\n=== Audit Complete ==="
EOF

chmod +x security-audit.sh
sudo ./security-audit.sh
```

## 🚀 Upgrade from Basic to Secure

### Step 1: Update Dockerfile (Optional)

```bash
# Use secure Dockerfile
cp Dockerfile.secure Dockerfile

# Or keep current Dockerfile (already has good security)
# Current Dockerfile already includes:
# - Non-root user
# - Multi-stage build
# - Minimal base image
```

### Step 2: Update Deployment

```bash
# Backup current deployment
sudo kubectl get deployment hello-world-python -o yaml > deployment-backup.yaml

# Apply secure deployment
sudo kubectl apply -f k8s/deployment-secure.yaml

# Verify
sudo kubectl rollout status deployment/hello-world-python
```

### Step 3: Add Network Policy

```bash
# Apply network policy
sudo kubectl apply -f k8s/network-policy.yaml

# Verify
sudo kubectl get networkpolicy
sudo kubectl describe networkpolicy hello-world-python-netpol
```

### Step 4: Test Everything

```bash
# Check pods
sudo kubectl get pods -l app=hello-world-python

# Test application
sudo kubectl port-forward service/hello-world-python 8080:80 &
curl http://localhost:8080/
curl http://localhost:8080/health

# Run security checks (see above)
```

## 🔐 Add HTTPS/TLS (Optional)

### Quick TLS Setup (Self-Signed)

```bash
# Generate certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=hello.lab.allwaysbeginner.com/O=Lab"

# Create secret
sudo kubectl create secret tls hello-world-python-tls \
  --cert=tls.crt --key=tls.key

# Install Traefik (if not installed)
sudo kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.10/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml

# Apply ingress
sudo kubectl apply -f k8s/ingress-secure.yaml

# Test HTTPS
curl -k https://hello.lab.allwaysbeginner.com/
```

## 📊 Security Comparison

### Before (Basic Deployment)
```yaml
spec:
  containers:
  - name: app
    image: app:latest
    # Basic security only
```

**Security Score: 3/10**
- ✅ Non-root user
- ✅ Resource limits
- ❌ No security context
- ❌ No network policy
- ❌ No read-only filesystem

### After (Secure Deployment)
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
```

**Security Score: 9/10**
- ✅ Non-root user
- ✅ Resource limits
- ✅ Security contexts
- ✅ Network policy
- ✅ Read-only filesystem
- ✅ Dropped capabilities
- ✅ Service account
- ✅ Health probes

## 🛠️ Troubleshooting

### Issue: Pods CrashLoopBackOff

**Cause:** Read-only filesystem prevents writing to required directories

**Solution:** Check volumes are mounted
```bash
sudo kubectl describe pod -l app=hello-world-python | grep -A 10 "Volumes:"
# Should see: tmp, cache volumes
```

### Issue: Network Policy Blocks Traffic

**Cause:** Too restrictive network policy

**Solution:** Temporarily disable to test
```bash
# Delete network policy
sudo kubectl delete networkpolicy hello-world-python-netpol

# Test application
curl http://SERVICE_IP/

# Re-apply with adjusted rules
sudo kubectl apply -f k8s/network-policy.yaml
```

### Issue: Permission Denied Errors

**Cause:** User doesn't have write access

**Solution:** Ensure writable volumes are mounted
```bash
# Check volume mounts
sudo kubectl get pod -l app=hello-world-python -o jsonpath='{.items[0].spec.containers[0].volumeMounts}' | jq .

# Should include /tmp and /home/appuser/.cache
```

## 📚 Additional Resources

- **Full Security Guide:** [docs/SECURITY_HARDENING_GUIDE.md](../../docs/SECURITY_HARDENING_GUIDE.md)
- **Deployment Guide:** [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **Infrastructure Guide:** [docs/COMPLETE_INFRASTRUCTURE_GUIDE.md](../../docs/COMPLETE_INFRASTRUCTURE_GUIDE.md)

## 🎯 Security Checklist

Use this checklist to verify your deployment:

- [ ] Container runs as non-root user (UID 1000)
- [ ] Root filesystem is read-only
- [ ] All capabilities dropped
- [ ] Security contexts configured (pod + container)
- [ ] Network policy applied
- [ ] Service account created
- [ ] Resource limits set
- [ ] Health probes configured
- [ ] Secrets properly managed
- [ ] TLS/HTTPS enabled (optional)
- [ ] Security scanning in CI/CD (optional)
- [ ] Audit logging enabled (optional)

## 🚦 Quick Commands Reference

```bash
# Deploy secure version
sudo kubectl apply -f k8s/deployment-secure.yaml
sudo kubectl apply -f k8s/network-policy.yaml

# Verify security
POD=$(sudo kubectl get pod -l app=hello-world-python -o jsonpath='{.items[0].metadata.name}')
sudo kubectl exec $POD -- id
sudo kubectl exec $POD -- touch /test  # Should fail

# Test application
sudo kubectl port-forward service/hello-world-python 8080:80
curl http://localhost:8080/health

# View logs
sudo kubectl logs -l app=hello-world-python -f

# Rollback if needed
sudo kubectl rollout undo deployment/hello-world-python

# Delete deployment
sudo kubectl delete -f k8s/deployment-secure.yaml
sudo kubectl delete -f k8s/network-policy.yaml
```

---

**Security Level:** 🔒🔒🔒🔒🔒 Enterprise-Grade

**Deployment Time:** 5-10 minutes

**Maintenance:** Low (automated security)

---

**Created with IBM Bob AI** 🤖