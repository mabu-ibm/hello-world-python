# Namespace Deployment Guide

All resources for the hello-world-python application are now deployed in a dedicated `hello-world-python` namespace.

## Quick Start

### Option 1: Using the Deployment Script (Recommended)

```bash
# Make the script executable
chmod +x k8s/deploy-with-namespace.sh

# Deploy with standard configuration
./k8s/deploy-with-namespace.sh standard

# Or deploy with secure configuration
./k8s/deploy-with-namespace.sh secure

# Or deploy with flexible configuration
./k8s/deploy-with-namespace.sh flexible
```

### Option 2: Manual Deployment

```bash
# 1. Create the namespace first
kubectl apply -f k8s/namespace.yaml

# 2. Create registry secret in the namespace (if needed)
kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild.lab.allwaysbeginner.com:3000 \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  --namespace=hello-world-python

# 3. Deploy the application (choose one)

# Standard deployment:
export IMAGE_REGISTRY="almabuild.lab.allwaysbeginner.com:3000"
export IMAGE_REPOSITORY="manfred/hello-world-python"
export IMAGE_TAG="latest"
export INGRESS_HOST="hello.lab.allwaysbeginner.com"
envsubst < k8s/deployment.yaml | kubectl apply -f -
envsubst < k8s/ingress.yaml | kubectl apply -f -

# OR Secure deployment:
kubectl apply -f k8s/deployment-secure.yaml
export INGRESS_HOST="hello.lab.allwaysbeginner.com"
envsubst < k8s/ingress-secure.yaml | kubectl apply -f -

# OR Flexible deployment:
export IMAGE_REGISTRY="almabuild.lab.allwaysbeginner.com:3000"
export IMAGE_REPOSITORY="manfred/hello-world-python"
export IMAGE_TAG="latest"
export INGRESS_HOST="hello.lab.allwaysbeginner.com"
envsubst < k8s/deployment.yaml | kubectl apply -f -
envsubst < k8s/ingress-flexible.yaml | kubectl apply -f -
```

## Namespace Benefits

1. **Isolation**: Resources are isolated from other applications
2. **Organization**: Easy to manage all related resources together
3. **Security**: Namespace-level RBAC and network policies
4. **Resource Quotas**: Can set limits per namespace
5. **Easy Cleanup**: Delete entire namespace to remove all resources

## Viewing Resources

```bash
# View all resources in the namespace
kubectl get all -n hello-world-python

# View pods
kubectl get pods -n hello-world-python

# View services
kubectl get svc -n hello-world-python

# View ingress
kubectl get ingress -n hello-world-python

# View logs
kubectl logs -n hello-world-python -l app=hello-world-python

# Describe a pod
kubectl describe pod -n hello-world-python -l app=hello-world-python
```

## Accessing the Application

### Internal Access (from within cluster)
```
http://hello-world-python.hello-world-python.svc.cluster.local
```

### External Access (via Ingress)
```
http://hello.lab.allwaysbeginner.com
https://hello.lab.allwaysbeginner.com
```

### NodePort Access (if using standard deployment)
```
http://<node-ip>:30080
```

## Troubleshooting

### Check namespace exists
```bash
kubectl get namespace hello-world-python
```

### Check if pods are running
```bash
kubectl get pods -n hello-world-python
```

### Check pod logs
```bash
kubectl logs -n hello-world-python -l app=hello-world-python --tail=50
```

### Check events
```bash
kubectl get events -n hello-world-python --sort-by='.lastTimestamp'
```

### Check ingress status
```bash
kubectl describe ingress hello-world-python -n hello-world-python
```

## Cleanup

To remove all resources:

```bash
# Delete the entire namespace (removes all resources)
kubectl delete namespace hello-world-python
```

Or delete individual resources:

```bash
# Delete deployment
kubectl delete deployment hello-world-python -n hello-world-python

# Delete service
kubectl delete service hello-world-python -n hello-world-python

# Delete ingress
kubectl delete ingress hello-world-python -n hello-world-python
```

## Updated Files

All the following files now use the `hello-world-python` namespace:

- `k8s/namespace.yaml` - Namespace definition (NEW)
- `k8s/deployment.yaml` - Standard deployment
- `k8s/deployment-secure.yaml` - Secure deployment with security contexts
- `k8s/ingress.yaml` - Standard ingress
- `k8s/ingress-secure.yaml` - Secure ingress with TLS and security headers
- `k8s/ingress-flexible.yaml` - Flexible ingress (HTTP/HTTPS)
- `k8s/deploy-with-namespace.sh` - Automated deployment script (NEW)

## Migration from Default Namespace

If you have existing resources in the `default` or `apps` namespace:

```bash
# Delete old resources
kubectl delete deployment hello-world-python -n default
kubectl delete service hello-world-python -n default
kubectl delete ingress hello-world-python -n default

# Or if in apps namespace
kubectl delete deployment hello-world-python -n apps
kubectl delete service hello-world-python -n apps
kubectl delete ingress hello-world-python -n apps

# Then deploy to new namespace using the script
./k8s/deploy-with-namespace.sh standard
```

# Made with Bob