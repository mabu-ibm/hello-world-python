# Quick Deployment Guide - Single Command

This guide shows you how to deploy everything in one command, including the namespace.

## Single-File Deployment (Easiest)

Use the combined deployment file that includes the namespace:

```bash
# Set your configuration
export IMAGE_REGISTRY="almabuild.lab.allwaysbeginner.com:3000"
export IMAGE_REPOSITORY="manfred/hello-world-python"
export IMAGE_TAG="latest"
export INGRESS_HOST="hello.lab.allwaysbeginner.com"

# Deploy everything in one command
envsubst < k8s/deployment-with-namespace.yaml | kubectl apply -f -
```

This will:
1. Create the `hello-world-python` namespace
2. Deploy the application
3. Create the service
4. Create the ingress

## Important: Registry Secret

Before deploying, you need to create the registry secret:

```bash
kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild.lab.allwaysbeginner.com:3000 \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  --namespace=hello-world-python
```

**Note**: If the namespace doesn't exist yet, create it first:

```bash
kubectl create namespace hello-world-python
```

Then create the secret, then deploy.

## Complete Deployment Steps

```bash
# Step 1: Create namespace
kubectl create namespace hello-world-python

# Step 2: Create registry secret
kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild.lab.allwaysbeginner.com:3000 \
  --docker-username=manfred \
  --docker-password=<your-password> \
  --namespace=hello-world-python

# Step 3: Deploy application
export IMAGE_REGISTRY="almabuild.lab.allwaysbeginner.com:3000"
export IMAGE_REPOSITORY="manfred/hello-world-python"
export IMAGE_TAG="latest"
export INGRESS_HOST="hello.lab.allwaysbeginner.com"
envsubst < k8s/deployment-with-namespace.yaml | kubectl apply -f -

# Step 4: Verify deployment
kubectl get all -n hello-world-python
kubectl get ingress -n hello-world-python
```

## Verify Deployment

```bash
# Check if pods are running
kubectl get pods -n hello-world-python

# Check service
kubectl get svc -n hello-world-python

# Check ingress
kubectl get ingress -n hello-world-python

# View logs
kubectl logs -n hello-world-python -l app=hello-world-python
```

## Access the Application

- **Internal**: http://hello-world-python.hello-world-python.svc.cluster.local
- **NodePort**: http://<node-ip>:30080
- **Ingress**: http://hello.lab.allwaysbeginner.com

## Cleanup

```bash
# Delete everything
kubectl delete namespace hello-world-python
```

## Troubleshooting

### Error: namespace not found

If you get "namespaces 'hello-world-python' not found", it means the namespace wasn't created. Run:

```bash
kubectl create namespace hello-world-python
```

Then try deploying again.

### Error: ImagePullBackOff

If pods show ImagePullBackOff, check the registry secret:

```bash
kubectl get secret gitea-registry -n hello-world-python
```

If it doesn't exist, create it as shown in Step 2 above.

### Check Pod Status

```bash
kubectl describe pod -n hello-world-python -l app=hello-world-python
```

# Made with Bob