# Fix HTTP 404 Error - Immediate Solution

## Problem

You're getting 404 on HTTP because the OLD ingress is still deployed with HTTP to HTTPS redirect.

## Quick Fix (Run This Now)

```bash
# Go to the project directory
cd project-templates/hello-world-python

# Run the fix script
chmod +x k8s/fix-ingress-now.sh
./k8s/fix-ingress-now.sh hello-world-python.lab.allwaysbeginner.com
```

## Or Manual Fix (Copy-Paste This)

```bash
# Delete old ingress
kubectl delete ingress hello-world-python-ingress -n default
kubectl delete ingress hello-world-python -n default

# Deploy flexible ingress
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-python-ingress
  namespace: default
  labels:
    app: hello-world-python
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  tls:
  - hosts:
    - hello-world-python.lab.allwaysbeginner.com
    secretName: hello-world-python-tls
  rules:
  - host: hello-world-python.lab.allwaysbeginner.com
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

# Test
curl http://hello-world-python.lab.allwaysbeginner.com
```

## Why You're Still Getting 404

The workflow changes are in the file, but:
- ❌ You haven't run the workflow again yet
- ❌ The OLD ingress is still deployed
- ❌ The OLD ingress redirects HTTP to HTTPS

## Solution

**Either:**

1. **Run the fix script NOW** (immediate fix)
   ```bash
   ./k8s/fix-ingress-now.sh
   ```

2. **OR push code to trigger workflow** (will fix on next run)
   ```bash
   git push
   ```

## After Fix

```bash
# HTTP should work
curl http://hello-world-python.lab.allwaysbeginner.com
# Should return HTML, not 404!

# HTTPS should also work
curl -k https://hello-world-python.lab.allwaysbeginner.com
```

## Verify Fix Worked

```bash
# Check ingress annotations
kubectl get ingress hello-world-python-ingress -n default -o jsonpath='{.metadata.annotations}' | jq .

# Should show:
# "traefik.ingress.kubernetes.io/router.entrypoints": "web,websecure"
# NOT: "traefik.ingress.kubernetes.io/redirect-entry-point": "https"
```

## Made with Bob