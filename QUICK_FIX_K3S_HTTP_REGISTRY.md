# Quick Fix: K3s HTTP Registry Error

## Error Message
```
http: server gave HTTP response to HTTPS client
```

## Root Cause
K3s nodes are trying to pull images via HTTPS, but your Gitea registry only supports HTTP.

## K3s-Specific Fix

K3s uses `/etc/rancher/k3s/registries.yaml` instead of Docker's `daemon.json`.

---

## Quick Fix (Manual - 3 minutes per node)

### Step 1: SSH to EACH K3s Node

You need to do this on **ALL** K3s nodes:

```bash
# SSH to the node
ssh almak3s  # or whatever your node hostname is
```

### Step 2: Create K3s Registries Config

```bash
# Create config directory if it doesn't exist
sudo mkdir -p /etc/rancher/k3s

# Edit the registries config
sudo nano /etc/rancher/k3s/registries.yaml
```

Add this content:

```yaml
mirrors:
  "almabuild2.lab.allwaysbeginner.com:3000":
    endpoint:
      - "http://almabuild2.lab.allwaysbeginner.com:3000"

configs:
  "almabuild2.lab.allwaysbeginner.com:3000":
    tls:
      insecure_skip_verify: true
```

**Important:** 
- Use exact registry hostname from your deployment
- Use `http://` in the endpoint
- Set `insecure_skip_verify: true`

Save and exit (Ctrl+X, Y, Enter in nano).

### Step 3: Restart K3s

```bash
# Restart K3s service
sudo systemctl restart k3s

# Wait a few seconds for K3s to be ready
sleep 10

# Verify K3s is running
sudo systemctl status k3s

# Should show: Active: active (running)
```

### Step 4: Test Registry Access

```bash
# Test if you can reach the registry
curl http://almabuild2.lab.allwaysbeginner.com:3000/v2/

# Should return: {} or authentication required message

# Test image pull with crictl (K3s container runtime)
sudo crictl pull almabuild2.lab.allwaysbeginner.com:3000/manfred/hello-world-python:latest
```

### Step 5: Repeat for All Nodes

**IMPORTANT:** Repeat steps 1-4 for EVERY K3s node in your cluster.

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

## Automated Fix (Recommended for K3s)

Use the K3s-specific automated script:

```bash
cd k8s
chmod +x fix-http-registry-k3s.sh

# Run the script (it will auto-detect nodes)
./fix-http-registry-k3s.sh

# Or specify nodes manually
K3S_NODES="almak3s node1 node2" ./fix-http-registry-k3s.sh
```

The script will:
- ✅ Detect all K3s nodes automatically
- ✅ Backup existing registries.yaml
- ✅ Create proper registries.yaml configuration
- ✅ Restart K3s on each node
- ✅ Verify configuration and test image pull

---

## Verification Checklist

After applying the fix, verify:

- [ ] registries.yaml exists on all nodes: `ssh <node> 'sudo cat /etc/rancher/k3s/registries.yaml'`
- [ ] K3s restarted successfully on all nodes: `ssh <node> 'sudo systemctl status k3s'`
- [ ] Can curl the registry from each node: `ssh <node> 'curl http://almabuild2.lab.allwaysbeginner.com:3000/v2/'`
- [ ] Pods deleted and recreated: `kubectl delete pods -l app=hello-world-python`
- [ ] New pods show Running status: `kubectl get pods`
- [ ] No ImagePullBackOff errors: `kubectl describe pod <pod-name>`

---

## K3s vs Docker Kubernetes

| Aspect | K3s | Docker Kubernetes |
|--------|-----|-------------------|
| Config File | `/etc/rancher/k3s/registries.yaml` | `/etc/docker/daemon.json` |
| Service | `k3s` | `docker` |
| Container Runtime | `containerd` | `docker` |
| Pull Command | `crictl pull` | `docker pull` |
| Restart Command | `systemctl restart k3s` | `systemctl restart docker` |

---

## Example registries.yaml

### Basic HTTP Registry (Your Case)

```yaml
mirrors:
  "almabuild2.lab.allwaysbeginner.com:3000":
    endpoint:
      - "http://almabuild2.lab.allwaysbeginner.com:3000"

configs:
  "almabuild2.lab.allwaysbeginner.com:3000":
    tls:
      insecure_skip_verify: true
```

### With Authentication

```yaml
mirrors:
  "almabuild2.lab.allwaysbeginner.com:3000":
    endpoint:
      - "http://almabuild2.lab.allwaysbeginner.com:3000"

configs:
  "almabuild2.lab.allwaysbeginner.com:3000":
    auth:
      username: manfred
      password: your-gitea-token
    tls:
      insecure_skip_verify: true
```

### Multiple Registries

```yaml
mirrors:
  "almabuild2.lab.allwaysbeginner.com:3000":
    endpoint:
      - "http://almabuild2.lab.allwaysbeginner.com:3000"
  "almabuild:5000":
    endpoint:
      - "http://almabuild:5000"

configs:
  "almabuild2.lab.allwaysbeginner.com:3000":
    tls:
      insecure_skip_verify: true
  "almabuild:5000":
    tls:
      insecure_skip_verify: true
```

---

## Common K3s Issues

### Issue: "Failed to pull image: rpc error"

**Cause:** K3s can't reach registry or wrong config

**Solution:**
```bash
# Check K3s logs
sudo journalctl -u k3s -n 100 -f

# Verify registries.yaml syntax
sudo cat /etc/rancher/k3s/registries.yaml

# Test with crictl
sudo crictl pull almabuild2.lab.allwaysbeginner.com:3000/manfred/hello-world-python:latest
```

### Issue: "x509: certificate signed by unknown authority"

**Cause:** K3s trying HTTPS with self-signed cert

**Solution:** Already handled by `insecure_skip_verify: true`

### Issue: "unauthorized: authentication required"

**Cause:** Missing credentials

**Solution:** Add auth section to registries.yaml:
```yaml
configs:
  "almabuild2.lab.allwaysbeginner.com:3000":
    auth:
      username: manfred
      password: your-gitea-token
    tls:
      insecure_skip_verify: true
```

---

## Debugging Commands

```bash
# Check K3s status
sudo systemctl status k3s

# View K3s logs
sudo journalctl -u k3s -n 50 -f

# Check registries config
sudo cat /etc/rancher/k3s/registries.yaml

# List images on node
sudo crictl images

# Pull image manually
sudo crictl pull almabuild2.lab.allwaysbeginner.com:3000/manfred/hello-world-python:latest

# Check containerd config
sudo cat /var/lib/rancher/k3s/agent/etc/containerd/config.toml

# Test registry connectivity
curl http://almabuild2.lab.allwaysbeginner.com:3000/v2/

# Check pod events
kubectl describe pod <pod-name> -n default

# View pod logs
kubectl logs <pod-name> -n default
```

---

## Quick Command Reference for K3s

```bash
# Configure node (manual)
ssh <node>
sudo mkdir -p /etc/rancher/k3s
sudo nano /etc/rancher/k3s/registries.yaml
# Add config from above
sudo systemctl restart k3s

# Delete failed pods
kubectl delete pods -l app=hello-world-python -n default

# Watch pods restart
kubectl get pods -n default -w

# Check pod events
kubectl describe pod <pod-name> -n default

# Test registry from node
ssh <node> 'curl http://almabuild2.lab.allwaysbeginner.com:3000/v2/'

# Test image pull from node
ssh <node> 'sudo crictl pull almabuild2.lab.allwaysbeginner.com:3000/manfred/hello-world-python:latest'
```

---

## After Fix is Applied

Once all nodes are configured:

1. **Delete old pods:**
   ```bash
   kubectl delete pods -l app=hello-world-python -n default
   ```

2. **Watch new pods start:**
   ```bash
   kubectl get pods -n default -w
   ```

3. **Verify running:**
   ```bash
   kubectl get pods -n default
   # Should show: Running
   ```

4. **Test the application:**
   ```bash
   kubectl get svc hello-world-python -n default
   curl http://<service-ip>:80
   ```

---

## Prevention for Future

To avoid this issue with new registries:

1. **Always configure registries.yaml** before deploying
2. **Use the automated script** for consistency
3. **Document registry URLs** in your deployment docs
4. **Test image pull manually** before deploying to K8s
5. **Keep registries.yaml in version control** (without credentials)

---

Made with ❤️ by IBM Bob