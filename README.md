# Hello World Python Flask Application

Simple Python Flask web application demonstrating CI/CD with Gitea Actions and Docker.

## Features

- ✅ Flask web application with JSON API
- ✅ Health check endpoints for Kubernetes
- ✅ Docker containerization with multi-stage build
- ✅ Non-root user for security
- ✅ Gitea Actions CI/CD pipeline
- ✅ Automated testing and image building
- ✅ Push to Gitea container registry

## Quick Start

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run application
python app.py

# Test endpoints
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/ready
```

### Docker Build

```bash
# Build image
docker build -t hello-world-python:latest .

# Run container
docker run -d -p 8080:8080 --name hello-app hello-world-python:latest

# Test
curl http://localhost:8080/

# Stop and remove
docker stop hello-app
docker rm hello-app
```

## API Endpoints

### GET /
Main hello world endpoint

**Response:**
```json
{
  "message": "Hello World from Python Flask!",
  "version": "1.0.0",
  "timestamp": "2026-03-27T17:00:00.000000",
  "status": "running"
}
```

### GET /health
Health check endpoint for Kubernetes liveness probe

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2026-03-27T17:00:00.000000"
}
```

### GET /ready
Readiness check endpoint for Kubernetes readiness probe

**Response:**
```json
{
  "status": "ready",
  "version": "1.0.0"
}
```

## Push to Gitea

### 1. Create Repository on Gitea

```bash
# Via web UI
1. Log into Gitea: http://almabuild:3000
2. Click "+" → "New Repository"
3. Name: hello-world-python
4. Click "Create Repository"
```

### 2. Configure Secrets

Add these secrets in Gitea repository settings:

- `GITEA_USERNAME`: Your Gitea username
- `GITEA_PASSWORD`: Your Gitea password or token

**Steps:**
1. Go to repository → Settings → Secrets
2. Add new secret: `GITEA_USERNAME`
3. Add new secret: `GITEA_PASSWORD`

### 3. Initialize and Push

```bash
# Initialize git
git init
git branch -M main

# Add files
git add .

# Commit
git commit -m "Initial commit: Hello World Python Flask app"

# Add remote (replace YOUR_USERNAME)
git remote add origin http://almabuild:3000/YOUR_USERNAME/hello-world-python.git

# Push
git push -u origin main
```

## CI/CD Pipeline

The Gitea Actions workflow (`.gitea/workflows/build-and-push.yaml`) automatically:

1. ✅ Checks out code
2. ✅ Sets up Python environment
3. ✅ Installs dependencies
4. ✅ Tests application import
5. ✅ Builds Docker image with commit SHA tag
6. ✅ Tests Docker image (health checks)
7. ✅ Logs into Gitea registry
8. ✅ Pushes images (SHA tag + latest)

### Workflow Triggers

- Push to `main` or `master` branch
- Pull requests to `main` or `master`

### Image Tags

- `almabuild:3000/YOUR_USERNAME/hello-world-python:COMMIT_SHA`
- `almabuild:3000/YOUR_USERNAME/hello-world-python:latest`

## Deployment to K3s

### Create Deployment

```bash
# Create deployment YAML
cat > deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-python
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-world-python
  template:
    metadata:
      labels:
        app: hello-world-python
    spec:
      imagePullSecrets:
      - name: gitea-registry
      containers:
      - name: hello-world-python
        image: almabuild:3000/YOUR_USERNAME/hello-world-python:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: hello-world-python
spec:
  selector:
    app: hello-world-python
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
EOF

# Apply to K3s
kubectl apply -f deployment.yaml
```

### Create Registry Secret

```bash
# Create secret for pulling images from Gitea
kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild:3000 \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  --docker-email=your-email@example.com
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -l app=hello-world-python

# Check service
kubectl get svc hello-world-python

# Test application
kubectl port-forward svc/hello-world-python 8080:80
curl http://localhost:8080/
```

## Auto-Update on New Image

### Option 1: Rollout Restart (Simplest)

Add to Gitea workflow after push:

```yaml
- name: Restart K3s deployment
  run: |
    kubectl rollout restart deployment/hello-world-python
    kubectl rollout status deployment/hello-world-python
```

### Option 2: Image Update with SHA

```yaml
- name: Update K3s deployment
  run: |
    kubectl set image deployment/hello-world-python \
      hello-world-python=almabuild:3000/${{ github.repository }}:${{ steps.tags.outputs.SHORT_SHA }}
    kubectl rollout status deployment/hello-world-python
```

## Project Structure

```
hello-world-python/
├── app.py                          # Flask application
├── requirements.txt                # Python dependencies
├── Dockerfile                      # Docker build instructions
├── .gitignore                      # Git ignore rules
├── .gitea/
│   └── workflows/
│       └── build-and-push.yaml    # CI/CD pipeline
└── README.md                       # This file
```

## Security Features

- ✅ Non-root user in container
- ✅ Multi-stage Docker build
- ✅ Minimal base image (python:3.11-slim)
- ✅ Health checks for monitoring
- ✅ Gunicorn production server
- ✅ No hardcoded secrets

## Monitoring

### View Logs

```bash
# Application logs
kubectl logs -l app=hello-world-python -f

# Specific pod
kubectl logs <pod-name> -f
```

### Check Health

```bash
# From within cluster
kubectl exec -it <pod-name> -- curl http://localhost:8080/health

# Via port-forward
kubectl port-forward svc/hello-world-python 8080:80
curl http://localhost:8080/health
```

## Troubleshooting

### Build Fails

```bash
# Check Gitea Actions logs
# Go to repository → Actions → Click on failed run

# Common issues:
# - Missing secrets (GITEA_USERNAME, GITEA_PASSWORD)
# - Wrong registry URL
# - Network connectivity
```

### Image Pull Fails

```bash
# Check secret
kubectl get secret gitea-registry -o yaml

# Recreate secret
kubectl delete secret gitea-registry
kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild:3000 \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD
```

### Pod Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Common issues:
# - Image pull errors
# - Port conflicts
# - Resource limits
```

## Next Steps

1. ✅ Push to Gitea
2. ✅ Watch CI/CD pipeline run
3. ✅ Verify image in registry
4. ✅ Deploy to K3s
5. ✅ Test application
6. ✅ Make changes and push again
7. ✅ Watch auto-deployment

## Resources

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Docker Documentation](https://docs.docker.com/)
- [Gitea Actions](https://docs.gitea.io/en-us/usage/actions/overview/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

**Created with IBM Bob AI** 🤖# Test
