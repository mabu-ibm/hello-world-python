# Troubleshooting App Access

## 🔍 Problem: Connection Refused on Port 30080

### Quick Diagnostics

Run these commands on your K3s machine to diagnose the issue:

```bash
# 1. Check if pods are running
kubectl get pods -n default -l app=hello-world-python

# 2. Check service
kubectl get service hello-world-python -n default

# 3. Check if NodePort is correctly configured
kubectl get service hello-world-python -n default -o yaml | grep nodePort

# 4. Check pod logs
kubectl logs -l app=hello-world-python -n default --tail=50

# 5. Check pod status
kubectl describe pod -l app=hello-world-python -n default
```

---

## Common Issues and Solutions

### Issue 1: Pods Not Running

**Check:**
```bash
kubectl get pods -n default -l app=hello-world-python
```

**If STATUS is not "Running":**

```bash
# Check why pods aren't starting
kubectl describe pod -l app=hello-world-python -n default

# Common causes:
# - ImagePullBackOff: Registry credentials missing
# - CrashLoopBackOff: Application error
# - Pending: Resource constraints
```

**Solutions:**

**A. ImagePullBackOff (Registry Credentials)**
```bash
# Create registry secret
kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild.lab.allwaysbeginner.com:3000 \
  --docker-username=manfred \
  --docker-password=YOUR_TOKEN \
  --namespace=default

# Update deployment to use secret
kubectl patch deployment hello-world-python -n default \
  -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"gitea-registry"}]}}}}'
```

**B. CrashLoopBackOff (Application Error)**
```bash
# Check logs
kubectl logs -l app=hello-world-python -n default --tail=100

# Common fixes:
# - Check if port 8080 is correct in deployment
# - Verify environment variables
# - Check if dependencies are installed
```

---

### Issue 2: Service Not Exposing NodePort

**Check service configuration:**
```bash
kubectl get service hello-world-python -n default -o yaml
```

**Should show:**
```yaml
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
```

**If NodePort is different or missing:**
```bash
# Delete and recreate service
kubectl delete service hello-world-python -n default
kubectl apply -f k8s/deployment.yaml
```

---

### Issue 3: Firewall Blocking Port 30080

**On K3s machine, check firewall:**

```bash
# Check if port is open
sudo netstat -tulpn | grep 30080

# For firewalld (AlmaLinux/RHEL)
sudo firewall-cmd --list-ports
sudo firewall-cmd --add-port=30080/tcp --permanent
sudo firewall-cmd --reload

# For ufw (Ubuntu)
sudo ufw allow 30080/tcp
sudo ufw reload

# For iptables
sudo iptables -A INPUT -p tcp --dport 30080 -j ACCEPT
sudo iptables-save
```

---

### Issue 4: Wrong IP Address

**Get correct K3s node IP:**
```bash
# On K3s machine
hostname -I

# Or
ip addr show | grep inet

# Or from kubectl
kubectl get nodes -o wide
```

**Test from K3s machine itself:**
```bash
# Test locally first
curl http://localhost:30080
curl http://127.0.0.1:30080

# If this works, it's a network/firewall issue
# If this doesn't work, it's a pod/service issue
```

---

### Issue 5: Service in Wrong Namespace

**Check all namespaces:**
```bash
kubectl get pods --all-namespaces | grep hello-world
kubectl get service --all-namespaces | grep hello-world
```

**If in wrong namespace:**
```bash
# Delete from wrong namespace
kubectl delete deployment hello-world-python -n WRONG_NAMESPACE
kubectl delete service hello-world-python -n WRONG_NAMESPACE

# Apply to correct namespace
kubectl apply -f k8s/deployment.yaml
```

---

## Step-by-Step Debugging

### Step 1: Verify Deployment Exists
```bash
kubectl get deployment hello-world-python -n default
```

**Expected output:**
```
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
hello-world-python    2/2     2            2           5m
```

### Step 2: Verify Pods are Running
```bash
kubectl get pods -n default -l app=hello-world-python
```

**Expected output:**
```
NAME                                  READY   STATUS    RESTARTS   AGE
hello-world-python-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
hello-world-python-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
```

### Step 3: Verify Service Exists
```bash
kubectl get service hello-world-python -n default
```

**Expected output:**
```
NAME                 TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
hello-world-python   NodePort   10.43.xxx.xxx   <none>        80:30080/TCP   5m
```

### Step 4: Test from Inside Cluster
```bash
# Get cluster IP
CLUSTER_IP=$(kubectl get service hello-world-python -n default -o jsonpath='{.spec.clusterIP}')

# Test from a debug pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://$CLUSTER_IP

# If this works, the app is running but NodePort might be blocked
```

### Step 5: Test NodePort from K3s Machine
```bash
# On K3s machine
curl http://localhost:30080
curl http://127.0.0.1:30080

# Should return HTML with "Hello World"
```

### Step 6: Test from External Machine
```bash
# From your MacBook
curl http://almak3s.lab.allwaysbeginner.com:30080

# Or
open http://almak3s.lab.allwaysbeginner.com:30080
```

---

## Complete Verification Script

Save this as `verify-deployment.sh` and run on K3s machine:

```bash
#!/bin/bash

echo "==================================="
echo "K3s Deployment Verification"
echo "==================================="

echo ""
echo "1. Checking deployment..."
kubectl get deployment hello-world-python -n default

echo ""
echo "2. Checking pods..."
kubectl get pods -n default -l app=hello-world-python

echo ""
echo "3. Checking service..."
kubectl get service hello-world-python -n default

echo ""
echo "4. Checking NodePort..."
NODE_PORT=$(kubectl get service hello-world-python -n default -o jsonpath='{.spec.ports[0].nodePort}')
echo "NodePort: $NODE_PORT"

echo ""
echo "5. Checking if port is listening..."
sudo netstat -tulpn | grep $NODE_PORT || echo "Port not listening!"

echo ""
echo "6. Testing locally..."
curl -s http://localhost:$NODE_PORT | head -n 5 || echo "Local test failed!"

echo ""
echo "7. Checking pod logs..."
kubectl logs -l app=hello-world-python -n default --tail=10

echo ""
echo "8. Node IP addresses..."
hostname -I

echo ""
echo "==================================="
echo "Access app at: http://$(hostname -I | awk '{print $1}'):$NODE_PORT"
echo "==================================="
```

---

## Quick Fixes

### Fix 1: Redeploy Everything
```bash
# Delete everything
kubectl delete -f k8s/deployment.yaml

# Wait a moment
sleep 5

# Reapply
kubectl apply -f k8s/deployment.yaml

# Wait for pods
kubectl wait --for=condition=ready pod -l app=hello-world-python -n default --timeout=2m

# Test
curl http://localhost:30080
```

### Fix 2: Check Image is Correct
```bash
# Verify image exists in registry
curl -u manfred:YOUR_TOKEN http://almabuild.lab.allwaysbeginner.com:3000/api/v1/repos/manfred/hello-world-python/packages

# Pull image manually to test
docker pull almabuild.lab.allwaysbeginner.com:3000/manfred/hello-world-python:latest
```

### Fix 3: Use Port Forward (Temporary)
```bash
# Forward port to test if app works
kubectl port-forward service/hello-world-python -n default 8080:80

# Test on K3s machine
curl http://localhost:8080

# If this works, NodePort configuration is the issue
```

---

## Expected Behavior

When everything is working:

1. **Pods**: 2/2 Running
2. **Service**: NodePort 30080
3. **Local test**: `curl http://localhost:30080` returns HTML
4. **External test**: `http://K3S_IP:30080` shows web page
5. **Button**: Click "Built by:" shows IBM Bob info

---

## Get Help

If still not working, gather this info:

```bash
# Run this and share output
kubectl get all -n default -l app=hello-world-python
kubectl describe pod -l app=hello-world-python -n default
kubectl logs -l app=hello-world-python -n default --tail=50
kubectl get service hello-world-python -n default -o yaml
sudo netstat -tulpn | grep 30080
hostname -I
```

---

**Made with ❤️ by IBM Bob Secure Skill** 🤖