# Secure HTTPS Setup Guide

Complete guide to access your application securely via HTTPS with TLS certificates.

---

## 🔒 Overview

For a **secure development demo with Bob**, we need:
1. ✅ HTTPS/TLS encryption
2. ✅ Network policies for security
3. ✅ Ingress controller (Traefik/Nginx)
4. ✅ TLS certificates
5. ✅ Secure access from external clients

---

## 🎯 Current Issue

**Problem:** Network policy blocks direct NodePort access (port 30080)
**Solution:** Use Ingress with TLS for secure HTTPS access

The network policy only allows:
- Ingress from kube-system (where ingress controller runs)
- Internal pod-to-pod communication

This is **correct for security** - external traffic should go through ingress controller with TLS.

---

## 🚀 Quick Setup (Recommended)

### Step 1: Check Ingress Controller

```bash
# Check if Traefik is installed (K3s default)
kubectl get pods -n kube-system | grep traefik

# Or check for Nginx
kubectl get pods -n kube-system | grep nginx
```

### Step 2: Deploy with Secure Ingress

```bash
# On almak3s machine
cd /path/to/hello-world-python

# Deploy application with secure ingress
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/ingress-secure.yaml
kubectl apply -f k8s/network-policy.yaml
```

### Step 3: Configure DNS

Add to your `/etc/hosts` (on MacBook):
```bash
# Get K3s IP
ssh manfred@almak3s.lab.allwaysbeginner.com "hostname -I | awk '{print \$1}'"

# Add to /etc/hosts on MacBook
sudo nano /etc/hosts

# Add this line (replace with actual IP):
192.168.1.100  hello-world.almak3s.local
```

### Step 4: Access Securely

```bash
# From MacBook
curl https://hello-world.almak3s.local

# Or in browser
open https://hello-world.almak3s.local
```

---

## 📋 Complete Secure Setup

### Option 1: Self-Signed Certificate (Quick Demo)

```bash
# On almak3s machine

# 1. Create self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=hello-world.almak3s.local/O=IBM Bob Demo"

# 2. Create TLS secret in Kubernetes
kubectl create secret tls hello-world-tls \
  --cert=tls.crt \
  --key=tls.key \
  --namespace=default

# 3. Deploy application
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/ingress-secure.yaml
kubectl apply -f k8s/network-policy.yaml

# 4. Verify ingress
kubectl get ingress -n default

# 5. Test (accept self-signed cert warning)
curl -k https://hello-world.almak3s.local
```

### Option 2: Let's Encrypt (Production)

```bash
# 1. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 2. Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=2m

# 3. Create Let's Encrypt issuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

# 4. Update ingress to use cert-manager
# Edit k8s/ingress-secure.yaml and add:
#   annotations:
#     cert-manager.io/cluster-issuer: "letsencrypt-prod"

# 5. Apply updated ingress
kubectl apply -f k8s/ingress-secure.yaml

# 6. Check certificate
kubectl get certificate -n default
kubectl describe certificate hello-world-tls -n default
```

---

## 🔧 Ingress Configuration

### Current ingress-secure.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-python-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  tls:
  - hosts:
    - hello-world.almak3s.local
    secretName: hello-world-tls
  rules:
  - host: hello-world.almak3s.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world-python
            port:
              number: 80
```

### For Nginx Ingress Controller

If using Nginx instead of Traefik:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-python-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - hello-world.almak3s.local
    secretName: hello-world-tls
  rules:
  - host: hello-world.almak3s.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world-python
            port:
              number: 80
```

---

## 🧪 Testing Secure Access

### From MacBook

```bash
# 1. Test DNS resolution
ping hello-world.almak3s.local

# 2. Test HTTPS (accept self-signed cert)
curl -k https://hello-world.almak3s.local

# 3. Test with certificate verification (after Let's Encrypt)
curl https://hello-world.almak3s.local

# 4. Open in browser
open https://hello-world.almak3s.local
```

### From almak3s

```bash
# 1. Check ingress
kubectl get ingress -n default

# 2. Check TLS secret
kubectl get secret hello-world-tls -n default

# 3. Test locally
curl -k https://hello-world.almak3s.local

# 4. Check ingress controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

---

## 🔍 Troubleshooting

### Issue: "Connection Refused" on Port 30080

**Cause:** Network policy blocks direct NodePort access (this is correct!)

**Solution:** Use HTTPS via ingress instead:
```bash
# Don't use: http://almak3s.lab.allwaysbeginner.com:30080
# Use instead: https://hello-world.almak3s.local
```

### Issue: "Certificate Not Valid"

**Cause:** Self-signed certificate

**Solutions:**
1. **For testing:** Use `-k` flag with curl: `curl -k https://...`
2. **For browser:** Click "Advanced" → "Proceed anyway"
3. **For production:** Use Let's Encrypt (see Option 2 above)

### Issue: "Host Not Found"

**Cause:** DNS not configured

**Solution:** Add to `/etc/hosts`:
```bash
# On MacBook
sudo nano /etc/hosts

# Add (replace with actual K3s IP):
192.168.1.100  hello-world.almak3s.local
```

### Issue: Ingress Not Working

**Check ingress controller:**
```bash
# For Traefik (K3s default)
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50

# Restart if needed
kubectl rollout restart deployment traefik -n kube-system
```

---

## 🎓 Security Best Practices

### ✅ What We Have (Secure)

1. **TLS Encryption** - All traffic encrypted
2. **Network Policies** - Restrict pod communication
3. **Ingress Controller** - Single entry point
4. **No Direct NodePort** - Forces traffic through ingress
5. **SBOM Generation** - Track dependencies
6. **Secure Container** - Non-root user, minimal image

### ✅ Additional Recommendations

1. **Use Let's Encrypt** - Free, trusted certificates
2. **Enable HSTS** - Force HTTPS in browsers
3. **Add WAF** - Web Application Firewall
4. **Enable mTLS** - Mutual TLS for service mesh
5. **Regular Updates** - Keep dependencies current
6. **Vulnerability Scanning** - Automated with Concert

---

## 📊 Architecture Diagram

```
┌─────────────┐
│   MacBook   │
│  (Browser)  │
└──────┬──────┘
       │ HTTPS (443)
       │ TLS Encrypted
       ▼
┌─────────────────────────────────┐
│         almak3s.local           │
│  ┌───────────────────────────┐  │
│  │   Ingress Controller      │  │
│  │   (Traefik/Nginx)         │  │
│  │   - TLS Termination       │  │
│  │   - Certificate           │  │
│  └───────────┬───────────────┘  │
│              │                   │
│  ┌───────────▼───────────────┐  │
│  │   Network Policy          │  │
│  │   - Allow from ingress    │  │
│  │   - Block direct access   │  │
│  └───────────┬───────────────┘  │
│              │                   │
│  ┌───────────▼───────────────┐  │
│  │   hello-world-python      │  │
│  │   Service (ClusterIP)     │  │
│  └───────────┬───────────────┘  │
│              │                   │
│  ┌───────────▼───────────────┐  │
│  │   Pods (2 replicas)       │  │
│  │   - Non-root user         │  │
│  │   - Read-only filesystem  │  │
│  │   - Security context      │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

---

## 🚀 Quick Commands Reference

```bash
# Deploy secure application
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/ingress-secure.yaml
kubectl apply -f k8s/network-policy.yaml

# Create self-signed cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=hello-world.almak3s.local/O=IBM Bob Demo"

# Create TLS secret
kubectl create secret tls hello-world-tls \
  --cert=tls.crt --key=tls.key -n default

# Check status
kubectl get ingress,svc,pods -n default

# Test access
curl -k https://hello-world.almak3s.local

# View logs
kubectl logs -l app=hello-world-python -n default
```

---

## 📖 Related Documentation

- **GIT_WORKFLOW.md** - Git operations
- **GITEA_SECRETS_SETUP.md** - CI/CD configuration
- **TROUBLESHOOTING_ACCESS.md** - General troubleshooting
- **SECURITY_SETUP.md** - Security hardening
- **SBOM_GENERATION_GUIDE.md** - SBOM and Concert integration

---

**Made with ❤️ by IBM Bob Secure Skill** 🤖🔒