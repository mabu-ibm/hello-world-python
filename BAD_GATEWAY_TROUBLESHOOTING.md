# Bad Gateway Troubleshooting Guide

## Problem
Getting "Bad Gateway" (502) error when accessing hello-world-python application through the browser, even though pods are running.

## Quick Diagnosis

Run the diagnostic script on the almak3s machine:
```bash
cd /path/to/project-templates/hello-world-python/k8s
chmod +x diagnose-bad-gateway.sh
./diagnose-bad-gateway.sh
```

## Quick Fix

Run the fix script on the almak3s machine:
```bash
cd /path/to/project-templates/hello-world-python/k8s
chmod +x fix-bad-gateway-now.sh
./fix-bad-gateway-now.sh
```

## Common Causes and Solutions

### 1. Service Port Mismatch
**Symptom**: Pods running, but service can't reach them

**Check**:
```bash
kubectl get svc hello-world-python -n default -o yaml
kubectl get pods -n default -l app=hello-world-python -o yaml | grep containerPort
```

**Expected**:
- Service port: 80
- Service targetPort: 8080
- Container port: 8080

**Fix**: Update service if ports don't match

### 2. Service Selector Mismatch
**Symptom**: Service endpoints are empty

**Check**:
```bash
kubectl get endpoints hello-world-python -n default
```

**Expected**: Should show pod IPs (e.g., 10.42.1.11:8080, 10.42.1.12:8080)

**Fix**:
```bash
# Check service selector
kubectl get svc hello-world-python -n default -o yaml | grep -A 3 selector

# Check pod labels
kubectl get pods -n default -l app=hello-world-python --show-labels
```

Both should have `app=hello-world-python`

### 3. Ingress Configuration Issues
**Symptom**: NodePort works, but ingress doesn't

**Check**:
```bash
kubectl describe ingress hello-world-python -n default
```

**Common Issues**:
- Wrong service name in backend
- Wrong service port
- Missing or incorrect annotations
- Wrong ingress class

**Fix**: Delete and recreate ingress:
```bash
kubectl delete ingress hello-world-python -n default

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-python
  namespace: default
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
  - host: almak3s
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world-python
            port:
              number: 80
EOF
```

### 4. Pod Health Check Failures
**Symptom**: Pods show as "Running" but not "Ready"

**Check**:
```bash
kubectl get pods -n default -l app=hello-world-python
kubectl describe pod <pod-name> -n default
```

**Fix**: Test health endpoints directly:
```bash
POD_NAME=$(kubectl get pods -n default -l app=hello-world-python -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n default $POD_NAME -- curl http://localhost:8080/health
kubectl exec -n default $POD_NAME -- curl http://localhost:8080/ready
```

If health checks fail, check application logs:
```bash
kubectl logs $POD_NAME -n default
```

### 5. Traefik Routing Issues
**Symptom**: Ingress created but Traefik not routing correctly

**Check Traefik logs**:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50
```

**Check Traefik configuration**:
```bash
kubectl get ingressroute -A
kubectl get middleware -A
```

**Fix**: Restart Traefik:
```bash
kubectl rollout restart deployment/traefik -n kube-system
```

### 6. Network Policy Blocking Traffic
**Symptom**: Pods can't communicate with each other or ingress

**Check**:
```bash
kubectl get networkpolicies -n default
```

**Fix**: If blocking policies exist, either update them or temporarily delete:
```bash
kubectl delete networkpolicy <policy-name> -n default
```

## Testing Access Methods

### 1. Direct Pod Access (from within cluster)
```bash
POD_IP=$(kubectl get pod <pod-name> -n default -o jsonpath='{.status.podIP}')
kubectl run test-curl --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl http://$POD_IP:8080/health
```

### 2. Service Access (from within cluster)
```bash
kubectl run test-curl --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl http://hello-world-python.default.svc.cluster.local/health
```

### 3. NodePort Access (from node)
```bash
NODE_PORT=$(kubectl get svc hello-world-python -n default -o jsonpath='{.spec.ports[0].nodePort}')
curl http://localhost:$NODE_PORT/health
```

### 4. Ingress Access (from anywhere)
```bash
# With hostname
curl -H 'Host: almak3s' http://192.168.8.31/health

# Or if DNS is configured
curl http://almak3s/health
```

## Step-by-Step Troubleshooting

1. **Verify pods are running and ready**:
   ```bash
   kubectl get pods -n default -l app=hello-world-python
   ```
   Expected: STATUS=Running, READY=1/1

2. **Check service endpoints**:
   ```bash
   kubectl get endpoints hello-world-python -n default
   ```
   Expected: Should list pod IPs

3. **Test NodePort access** (this bypasses ingress):
   ```bash
   NODE_PORT=$(kubectl get svc hello-world-python -n default -o jsonpath='{.spec.ports[0].nodePort}')
   curl http://localhost:$NODE_PORT/health
   ```
   If this works, the problem is with ingress, not the app

4. **Check ingress configuration**:
   ```bash
   kubectl describe ingress hello-world-python -n default
   ```
   Verify:
   - Backend points to correct service
   - Service port is 80
   - Endpoints are populated

5. **Check Traefik logs**:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50 | grep hello-world
   ```

6. **Test with curl using Host header**:
   ```bash
   curl -v -H 'Host: almak3s' http://192.168.8.31/health
   ```

## Most Likely Cause

Based on your symptoms (pods running, Bad Gateway error), the most likely causes are:

1. **Ingress annotation issue** - Missing or incorrect Traefik annotations
2. **Service port mismatch** - Service not correctly routing to pod port
3. **Traefik routing issue** - Traefik not picking up the ingress configuration

## Recommended Fix Order

1. Run the diagnostic script to identify the exact issue
2. Run the quick fix script to recreate the ingress with correct configuration
3. Test NodePort access first (should work if pods are healthy)
4. Test ingress access with Host header
5. Check Traefik logs if still failing

## Additional Resources

- Check pod logs: `kubectl logs <pod-name> -n default`
- Check service: `kubectl get svc hello-world-python -n default -o yaml`
- Check ingress: `kubectl get ingress hello-world-python -n default -o yaml`
- Check Traefik: `kubectl get all -n kube-system -l app.kubernetes.io/name=traefik`

## Success Indicators

When fixed, you should see:
- ✓ Pods: Running and Ready (1/1)
- ✓ Service endpoints: Populated with pod IPs
- ✓ NodePort: Returns 200 OK with health check response
- ✓ Ingress: Returns 200 OK when accessed with Host header
- ✓ Browser: Shows the Hello World application

## Need More Help?

If the issue persists after trying these solutions:
1. Run the diagnostic script and save the output
2. Check all pod logs for errors
3. Verify the Docker image is correct and working
4. Check if there are any firewall rules blocking traffic
5. Verify Traefik is running correctly in kube-system namespace