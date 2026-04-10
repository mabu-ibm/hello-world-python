# Quick Fix: HTTP Registry Error

## Error Message
```
http: server gave HTTP response to HTTPS client
```

## Root Cause
Kubernetes nodes are trying to pull images via HTTPS, but your Gitea registry only supports HTTP.

## Quick Fix (Manual - 5 minutes)

### Step 1: SSH to EACH Kubernetes Node

You need to do this on **ALL** nodes (master and workers):

```bash
# SSH to the node
ssh almak3s  # or whatever your node hostname is
```

### Step 2: Edit Docker Daemon Config

```bash
# Edit the Docker daemon config
sudo nano /etc/docker/daemon.json
```

Add or update to include your registry as insecure:

```json
{
  "insecure-registries": [
    "almabuild2.lab.allwaysbeginner.com:3000"
  ]
}
```

**If the file already has content**, merge it like this:

```json
{
  "insecure-registries": [
    "almabuild2.lab.allwaysbeginner.com:3000",
    "almabuild:5000"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

Save and exit (Ctrl+X, Y, Enter in nano).

### Step 3: Restart Docker

```bash
# Restart Docker daemon
sudo systemctl restart docker

# Verify Docker is running
sudo systemctl status docker

# Should show: Active: active (running)
```

### Step 4: Test Registry Access

```bash
# Test if you can reach the registry
curl http://almabuild2.lab.allwaysbeginner.com:3000/v2/

# Should return: {} or authentication required message
```

### Step 5: Repeat for All Nodes

**IMPORTANT:** Repeat steps 1-4 for EVERY Kubernetes node in your cluster.

### Step 6: Delete Failed Pods

After configuring all nodes, delete the failed pods to force a re-pull:

```bash
# Delete all hello-world-python pods
kubectl delete pods -l app=hello-world-python -n default

# Watch them come back up
kubectl get pods -n default -w

# Should show: Running status within 30 seconds
```

### Step 7: Verify Success

```bash
# Check pod status
kubectl get pods -n default

# Should show:
# NAME                                  READY   STATUS    RESTARTS   AGE
# hello-world-python-6b76876d77-xxxxx   1/1     Running   0          1m

# If still failing, check events
kubectl describe pod <pod-name> -n default
```

---

## Automated Fix (Recommended)

Use the automated script to configure all nodes at once:

```bash
cd k8s
chmod +x fix-http-registry-k8s-nodes.sh

# Run the script (it will auto-detect nodes)
./fix-http-registry-k8s-nodes.sh

# Or specify nodes manually
K8S_NODES="almak3s node1 node2" ./fix-http-registry-k8s-nodes.sh
```

The script will:
- ✅ Detect all K8s nodes automatically
- ✅ Backup existing Docker configs
- ✅ Add insecure registry configuration
- ✅ Restart Docker on each node
- ✅ Verify configuration

---

## For K3s Users

If you're using K3s instead of Docker, the configuration is different:

```bash
# SSH to each K3s node
ssh <k3s-node>

# Create or edit registries config
sudo nano /etc/rancher/k3s/registries.yaml

# Add this content:
mirrors:
  "almabuild2.lab.allwaysbeginner.com:3000":
    endpoint:
      - "http://almabuild2.lab.allwaysbeginner.com:3000"

configs:
  "almabuild2.lab.allwaysbeginner.com:3000":
    tls:
      insecure_skip_verify: true

# Save and restart K3s
sudo systemctl restart k3s

# Verify
sudo systemctl status k3s
```

---

## Verification Checklist

After applying the fix, verify:

- [ ] Docker daemon.json includes your registry in insecure-registries
- [ ] Docker restarted successfully on all nodes
- [ ] Can curl the registry from each node: `curl http://almabuild2.lab.allwaysbeginner.com:3000/v2/`
- [ ] Pods deleted and recreated: `kubectl delete pods -l app=hello-world-python`
- [ ] New pods show Running status: `kubectl get pods`
- [ ] No ImagePullBackOff errors: `kubectl describe pod <pod-name>`

---

## Why This Happens

1. **Docker defaults to HTTPS** for security
2. **Your Gitea registry uses HTTP** (no SSL certificate)
3. **Docker refuses HTTP** unless explicitly told it's safe
4. **Solution:** Add registry to "insecure-registries" list

---

## Alternative: Enable HTTPS on Gitea (Better Security)

For production, consider enabling HTTPS on Gitea:

```bash
# On almabuild2
sudo nano /etc/gitea/app.ini

# Update [server] section:
[server]
PROTOCOL = https
CERT_FILE = /path/to/cert.pem
KEY_FILE = /path/to/key.pem
```

Then you won't need insecure-registries configuration.

---

## Common Mistakes

❌ **Only configuring master node** - Must configure ALL nodes
❌ **Forgetting to restart Docker** - Changes don't apply until restart
❌ **Wrong registry hostname** - Must match exactly what's in deployment
❌ **Not deleting old pods** - Old pods won't retry with new config

---

## Still Not Working?

If pods still fail after this fix:

1. **Check if secret exists:**
   ```bash
   kubectl get secret registry-credentials -n default
   ```

2. **Verify deployment has imagePullSecrets:**
   ```bash
   kubectl get deployment hello-world-python -n default -o yaml | grep imagePullSecrets
   ```

3. **Check if image exists in registry:**
   ```bash
   curl -u manfred:token http://almabuild2.lab.allwaysbeginner.com:3000/v2/manfred/hello-world-python/tags/list
   ```

4. **View detailed pod events:**
   ```bash
   kubectl describe pod <pod-name> -n default | tail -30
   ```

---

## Quick Command Reference

```bash
# Configure node (manual)
ssh <node>
sudo nano /etc/docker/daemon.json
# Add: {"insecure-registries": ["almabuild2.lab.allwaysbeginner.com:3000"]}
sudo systemctl restart docker

# Delete failed pods
kubectl delete pods -l app=hello-world-python -n default

# Watch pods restart
kubectl get pods -n default -w

# Check pod events
kubectl describe pod <pod-name> -n default

# Test registry from node
ssh <node> 'curl http://almabuild2.lab.allwaysbeginner.com:3000/v2/'
```

---

Made with ❤️ by IBM Bob