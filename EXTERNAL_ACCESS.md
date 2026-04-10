# External Access Guide - Kubernetes Deployment

## 🌐 How to Access the App from Outside Kubernetes

The app is deployed with **NodePort** service type by default, making it accessible from your K3s machine's IP address.

## ✅ Default Access Method: NodePort (Port 30080)

### Quick Access

```bash
# Get your K3s machine IP
K3S_IP=<your-k3s-machine-ip>  # e.g., 192.168.1.100

# Access the app
open http://$K3S_IP:30080

# Or with curl
curl http://$K3S_IP:30080
```

### Example
```bash
# If your K3s machine IP is 192.168.1.100
open http://192.168.1.100:30080
```

### Verify Deployment

```bash
# Check if service is running
kubectl get service hello-world-python -n default

# Should show:
# NAME                  TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# hello-world-python    NodePort   10.43.xxx.xxx   <none>        80:30080/TCP   1m

# Check pods are running
kubectl get pods -l app=hello-world-python -n default
```

---

## Alternative Access Methods

There are several other ways to expose your application if needed:

---

## Option 1: Ingress (Recommended for Production)

### Step 1: Apply Ingress Configuration

```bash
# Apply the ingress
kubectl apply -f k8s/ingress.yaml

# Verify ingress is created
kubectl get ingress -n apps
```

### Step 2: Configure DNS/Hosts File

**Option A: Add to /etc/hosts (Local Testing)**
```bash
# Get your K3s node IP
K3S_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Add to /etc/hosts
echo "$K3S_IP hello-world-python.local" | sudo tee -a /etc/hosts
```

**Option B: Configure Real DNS (Production)**
```bash
# Point your domain to K3s node IP
# Example: hello-world-python.yourdomain.com → 192.168.1.100
```

### Step 3: Access the App

```bash
# HTTP access
open http://hello-world-python.local

# Or with curl
curl http://hello-world-python.local
```

### Step 4: Enable HTTPS (Optional)

```bash
# Install cert-manager for automatic TLS
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
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

# Update ingress.yaml to use TLS
# Uncomment the tls section and apply
```

---

## Option 2: NodePort (Simple, No Ingress Controller Needed)

### Step 1: Change Service Type

```bash
# Edit service to use NodePort
kubectl patch service hello-world-python -n apps -p '{"spec":{"type":"NodePort"}}'

# Get the NodePort
NODE_PORT=$(kubectl get service hello-world-python -n apps -o jsonpath='{.spec.ports[0].nodePort}')
echo "NodePort: $NODE_PORT"
```

### Step 2: Access the App

```bash
# Get K3s node IP
K3S_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Access the app
open http://$K3S_IP:$NODE_PORT

# Or with curl
curl http://$K3S_IP:$NODE_PORT
```

**Example:**
```bash
# If K3S_IP=192.168.1.100 and NODE_PORT=30080
open http://192.168.1.100:30080
```

---

## Option 3: LoadBalancer (Cloud or MetalLB)

### For Cloud Providers (AWS, GCP, Azure)

```bash
# Change service type to LoadBalancer
kubectl patch service hello-world-python -n apps -p '{"spec":{"type":"LoadBalancer"}}'

# Wait for external IP
kubectl get service hello-world-python -n apps --watch

# Access via external IP
EXTERNAL_IP=$(kubectl get service hello-world-python -n apps -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
open http://$EXTERNAL_IP
```

### For On-Premise (MetalLB)

```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Configure IP address pool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.200-192.168.1.250  # Change to your network range
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF

# Change service type
kubectl patch service hello-world-python -n apps -p '{"spec":{"type":"LoadBalancer"}}'

# Get assigned IP
kubectl get service hello-world-python -n apps
```

---

## Option 4: Port Forward (Development/Testing)

```bash
# Forward local port to service
kubectl port-forward service/hello-world-python -n apps 8080:80

# Access locally
open http://localhost:8080
```

**Note:** This only works while the command is running and only from your local machine.

---

## Comparison of Methods

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **Ingress** | Production | Domain-based routing, TLS, multiple apps | Requires ingress controller |
| **NodePort** | Simple external access | Easy setup, no extra components | Uses high ports (30000-32767) |
| **LoadBalancer** | Cloud/Production | Clean external IP, standard ports | Requires cloud provider or MetalLB |
| **Port Forward** | Development only | Quick testing | Only local access, not persistent |

---

## Recommended Setup for Different Scenarios

### Development/Testing
```bash
# Use port-forward for quick testing
kubectl port-forward service/hello-world-python -n apps 8080:80
```

### Internal Network Access
```bash
# Use NodePort
kubectl patch service hello-world-python -n apps -p '{"spec":{"type":"NodePort"}}'
# Access via http://K3S_IP:NODE_PORT
```

### Production (On-Premise)
```bash
# Use Ingress with custom domain
kubectl apply -f k8s/ingress.yaml
# Configure DNS: app.yourdomain.com → K3S_IP
# Access via http://app.yourdomain.com
```

### Production (Cloud)
```bash
# Use LoadBalancer
kubectl patch service hello-world-python -n apps -p '{"spec":{"type":"LoadBalancer"}}'
# Access via external IP provided by cloud
```

---

## Complete Example: Ingress Setup

```bash
# 1. Deploy the application
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# 2. Apply ingress
kubectl apply -f k8s/ingress.yaml

# 3. Get K3s IP
K3S_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "K3s IP: $K3S_IP"

# 4. Add to /etc/hosts
echo "$K3S_IP hello-world-python.local" | sudo tee -a /etc/hosts

# 5. Test access
curl http://hello-world-python.local

# 6. Open in browser
open http://hello-world-python.local
```

---

## Troubleshooting

### Ingress Not Working

```bash
# Check ingress controller is running (K3s uses Traefik by default)
kubectl get pods -n kube-system | grep traefik

# Check ingress status
kubectl describe ingress hello-world-python -n apps

# Check service endpoints
kubectl get endpoints hello-world-python -n apps
```

### NodePort Not Accessible

```bash
# Check firewall rules
sudo ufw status
sudo ufw allow 30000:32767/tcp

# Verify service
kubectl get service hello-world-python -n apps

# Test from K3s node
curl localhost:NODE_PORT
```

### LoadBalancer Pending

```bash
# Check if MetalLB is installed
kubectl get pods -n metallb-system

# Check service events
kubectl describe service hello-world-python -n apps

# Verify IP pool configuration
kubectl get ipaddresspool -n metallb-system
```

---

## Security Considerations

### Enable TLS/HTTPS
```bash
# Use cert-manager for automatic certificates
# See Step 4 in Option 1 above
```

### Restrict Access by IP
```yaml
# Add to ingress annotations
nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,192.168.0.0/16"
```

### Enable Authentication
```yaml
# Add basic auth to ingress
nginx.ingress.kubernetes.io/auth-type: basic
nginx.ingress.kubernetes.io/auth-secret: basic-auth
nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required'
```

---

## Quick Reference

```bash
# Get K3s node IP
kubectl get nodes -o wide

# Get service details
kubectl get service hello-world-python -n apps

# Get ingress details
kubectl get ingress hello-world-python -n apps

# Test from inside cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://hello-world-python.apps.svc.cluster.local

# View logs
kubectl logs -l app=hello-world-python -n apps --tail=50 -f
```

---

**Made with ❤️ by IBM Bob Secure Skill** 🤖