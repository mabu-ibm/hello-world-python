# Flexible Ingress Configuration Guide

## Overview

The flexible ingress configuration (`ingress-flexible.yaml`) accepts **both HTTP and HTTPS** traffic and works across different K3s clusters without modification.

## Key Features

✅ **Accepts HTTP and HTTPS** - No forced redirect  
✅ **Works with or without TLS certificate** - Self-signed cert support  
✅ **Multi-cluster compatible** - Works on any K3s cluster  
✅ **Traefik and Nginx compatible** - Auto-detects ingress controller  
✅ **Configurable hostname** - Easy to customize  
✅ **Optional security headers** - Can be enabled if needed  

## Quick Start

### Option 1: Using the Deployment Script (Recommended)

```bash
# Make script executable
chmod +x k8s/deploy-flexible.sh

# Deploy with defaults
./k8s/deploy-flexible.sh

# Deploy with custom hostname
./k8s/deploy-flexible.sh myapp.example.com

# Deploy with custom registry and hostname
./k8s/deploy-flexible.sh myapp.example.com registry.example.com:5000

# Deploy with all custom parameters
./k8s/deploy-flexible.sh \
  myapp.example.com \
  registry.example.com:5000 \
  my-app \
  v1.0.0 \
  production
```

### Option 2: Manual Deployment

```bash
# 1. Set your hostname
export INGRESS_HOST="hello-world-python.lab.allwaysbeginner.com"

# 2. Deploy application
sed "s/\${INGRESS_HOST}/${INGRESS_HOST}/g" k8s/ingress-flexible.yaml | kubectl apply -f -

# 3. Create TLS certificate (optional but recommended)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=${INGRESS_HOST}/O=MyOrg"

kubectl create secret tls hello-world-python-tls \
  --cert=tls.crt --key=tls.key -n default

rm tls.key tls.crt
```

## Configuration Details

### Ingress Annotations

The flexible ingress uses these key annotations:

```yaml
annotations:
  # Accept BOTH HTTP and HTTPS
  traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
  
  # Enable TLS but don't force it
  traefik.ingress.kubernetes.io/router.tls: "true"
  
  # NO HTTP to HTTPS redirect (this is the key!)
  # traefik.ingress.kubernetes.io/redirect-entry-point: https  # COMMENTED OUT
  
  # Nginx compatibility
  nginx.ingress.kubernetes.io/ssl-redirect: "false"
  nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
```

### TLS Configuration

The ingress includes optional TLS:

```yaml
tls:
- hosts:
  - ${INGRESS_HOST}
  secretName: hello-world-python-tls  # Works even if secret doesn't exist
```

**Behavior:**
- If TLS secret exists → HTTPS works with that certificate
- If TLS secret doesn't exist → HTTPS works with Traefik's default cert
- HTTP always works regardless of TLS configuration

## Access Methods

### 1. HTTP Access (Always Works)

```bash
# From command line
curl http://hello-world-python.lab.allwaysbeginner.com

# From browser
http://hello-world-python.lab.allwaysbeginner.com
```

### 2. HTTPS Access (Always Works)

```bash
# From command line (ignore self-signed cert)
curl -k https://hello-world-python.lab.allwaysbeginner.com

# From browser (accept security warning)
https://hello-world-python.lab.allwaysbeginner.com
```

### 3. Direct IP Access (Optional)

To enable access via cluster IP without hostname, uncomment this section in `ingress-flexible.yaml`:

```yaml
# Uncomment for IP-based access
- http:
    paths:
    - path: /
      pathType: Prefix
      backend:
        service:
          name: hello-world-python
          port:
            number: 80
```

Then access via: `http://<CLUSTER_IP>` or `https://<CLUSTER_IP>`

## Multi-Cluster Deployment

### Scenario 1: Different Hostnames per Cluster

```bash
# Cluster 1 (Development)
./k8s/deploy-flexible.sh dev-app.example.com

# Cluster 2 (Staging)
./k8s/deploy-flexible.sh staging-app.example.com

# Cluster 3 (Production)
./k8s/deploy-flexible.sh app.example.com
```

### Scenario 2: Same Hostname, Different Clusters

```bash
# Deploy to Cluster 1
kubectl config use-context cluster1
./k8s/deploy-flexible.sh myapp.example.com

# Deploy to Cluster 2
kubectl config use-context cluster2
./k8s/deploy-flexible.sh myapp.example.com

# Deploy to Cluster 3
kubectl config use-context cluster3
./k8s/deploy-flexible.sh myapp.example.com
```

Update DNS or /etc/hosts to point to the desired cluster.

### Scenario 3: Multiple Apps per Cluster

```bash
# App 1
./k8s/deploy-flexible.sh app1.example.com registry.example.com:5000 app1

# App 2
./k8s/deploy-flexible.sh app2.example.com registry.example.com:5000 app2

# App 3
./k8s/deploy-flexible.sh app3.example.com registry.example.com:5000 app3
```

## DNS Configuration

### Option 1: /etc/hosts (Development)

```bash
# Get cluster IP
CLUSTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Add to /etc/hosts
echo "${CLUSTER_IP}  hello-world-python.lab.allwaysbeginner.com" | sudo tee -a /etc/hosts
```

### Option 2: CoreDNS (Cluster-wide)

Use the CoreDNS configuration script:

```bash
# Add entries to /etc/hosts on K3s node
sudo nano /etc/hosts
# Add: 192.168.1.100 hello-world-python.lab.allwaysbeginner.com

# Configure CoreDNS
sudo ./k8s-setup/configure-coredns-simple.sh
```

### Option 3: Real DNS (Production)

Create DNS A records pointing to your cluster's external IP:

```
hello-world-python.lab.allwaysbeginner.com  A  <EXTERNAL_IP>
```

## Ingress Controller Compatibility

### Traefik (K3s Default)

Works out of the box. Traefik is the default ingress controller in K3s.

```bash
# Verify Traefik is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
```

### Nginx Ingress

If your cluster uses Nginx instead of Traefik:

1. The ingress includes Nginx-compatible annotations
2. Optionally uncomment `ingressClassName: nginx` in the ingress spec
3. Deploy normally - it will work with both controllers

```bash
# Verify Nginx is running
kubectl get pods -n ingress-nginx
```

## Security Considerations

### 1. Enable Security Headers (Optional)

Uncomment the security headers middleware in `ingress-flexible.yaml`:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: hello-world-security-headers
  namespace: default
spec:
  headers:
    customResponseHeaders:
      X-Content-Type-Options: "nosniff"
      X-Frame-Options: "SAMEORIGIN"
      X-XSS-Protection: "1; mode=block"
```

Then add to ingress annotations:

```yaml
annotations:
  traefik.ingress.kubernetes.io/router.middlewares: default-hello-world-security-headers@kubernetescrd
```

### 2. Force HTTPS (If Needed)

To force HTTPS redirect, uncomment in annotations:

```yaml
annotations:
  traefik.ingress.kubernetes.io/redirect-entry-point: https
  traefik.ingress.kubernetes.io/redirect-permanent: "true"
```

### 3. Use Real TLS Certificate

For production, use cert-manager with Let's Encrypt:

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Add annotation to ingress
cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

## Troubleshooting

### Issue 1: Cannot Access via HTTP

**Check:**
```bash
# Verify entrypoints include 'web'
kubectl get ingress hello-world-python -n default -o yaml | grep entrypoints
```

**Should show:** `web,websecure`

### Issue 2: Cannot Access via HTTPS

**Check:**
```bash
# Verify TLS is enabled
kubectl get ingress hello-world-python -n default -o yaml | grep tls

# Check if certificate exists
kubectl get secret hello-world-python-tls -n default
```

### Issue 3: 404 Not Found

**Check:**
```bash
# Verify service exists
kubectl get service hello-world-python -n default

# Verify pods are running
kubectl get pods -l app=hello-world-python -n default

# Check ingress rules
kubectl describe ingress hello-world-python -n default
```

### Issue 4: Different Cluster, Same Config Not Working

**Possible causes:**
1. Different ingress controller (Traefik vs Nginx)
2. Different namespace
3. Different service name
4. Firewall blocking ports 80/443

**Solution:**
```bash
# Check ingress controller
kubectl get pods -A | grep -E 'traefik|nginx'

# Check if ports are open
curl -v http://<CLUSTER_IP>
curl -kv https://<CLUSTER_IP>
```

## Testing

### Test HTTP Access

```bash
# From inside cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  wget -O- http://hello-world-python.default.svc.cluster.local

# From outside cluster
curl http://hello-world-python.lab.allwaysbeginner.com
```

### Test HTTPS Access

```bash
# Ignore self-signed certificate
curl -k https://hello-world-python.lab.allwaysbeginner.com

# Show certificate details
openssl s_client -connect hello-world-python.lab.allwaysbeginner.com:443 -servername hello-world-python.lab.allwaysbeginner.com
```

### Test Both Protocols

```bash
# HTTP
curl -I http://hello-world-python.lab.allwaysbeginner.com

# HTTPS
curl -Ik https://hello-world-python.lab.allwaysbeginner.com
```

## Examples

### Example 1: Deploy to Dev Cluster

```bash
./k8s/deploy-flexible.sh \
  dev-hello.lab.allwaysbeginner.com \
  dev-registry.lab.allwaysbeginner.com:5000 \
  hello-world-python \
  dev-latest \
  development
```

### Example 2: Deploy to Prod Cluster

```bash
./k8s/deploy-flexible.sh \
  hello.production.com \
  registry.production.com \
  hello-world-python \
  v1.2.3 \
  production
```

### Example 3: Deploy Multiple Instances

```bash
# Instance 1
./k8s/deploy-flexible.sh app1.example.com

# Instance 2
./k8s/deploy-flexible.sh app2.example.com

# Instance 3
./k8s/deploy-flexible.sh app3.example.com
```

## Summary

✅ **HTTP and HTTPS both work** - No forced redirect  
✅ **Self-signed certificates supported** - No cert-manager required  
✅ **Works on any K3s cluster** - Traefik or Nginx  
✅ **Easy to configure** - Single hostname parameter  
✅ **Production ready** - Can add real certs and security headers  

The flexible ingress is designed to "just work" across different environments while still allowing customization for production use.

## Made with Bob