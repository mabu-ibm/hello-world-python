# Quick Start Guide - Hello World Python App

## 🚀 How to Access the App

### Option 1: Local Development (Fastest)

```bash
# 1. Navigate to the project
cd project-templates/hello-world-python

# 2. Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Run the app
python app.py

# 5. Open in browser
open http://localhost:8080
# Or visit: http://localhost:8080
```

**Click the "Built by:" button to see IBM Bob Secure Skill info!**

---

### Option 2: Docker (Recommended)

```bash
# 1. Build the image
docker build -t hello-world-python:latest .

# 2. Run the container
docker run -p 8080:8080 hello-world-python:latest

# 3. Access the app
open http://localhost:8080
```

---

### Option 3: Deploy with Bob Skill (Full Pipeline)

```bash
# 1. Set environment variables
export GITEA_USER=your-username
export GITEA_TOKEN=your-token

# 2. Deploy with Bob
cd ~/dev-infrastructure-setup
./bob-skill/deploy-secure-app.sh my-app python

# 3. Wait for deployment (~3-5 minutes)
# Watch pipeline at: http://almabuild:3000/your-username/my-app/actions

# 4. Access via Kubernetes
kubectl port-forward service/my-app 8080:80

# 5. Open in browser
open http://localhost:8080
```

---

### Option 4: Kubernetes Deployment

```bash
# 1. Apply Kubernetes manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# 2. Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=hello-world-python --timeout=60s

# 3. Port forward to access
kubectl port-forward service/hello-world-python 8080:80

# 4. Open in browser
open http://localhost:8080
```

---

## 📱 Available Endpoints

Once the app is running, you can access:

### Web UI (Interactive)
- **URL**: http://localhost:8080
- **Features**: 
  - Beautiful gradient design
  - Interactive "Built by:" button
  - Shows version and status
  - Links to API and health checks

### JSON API
- **URL**: http://localhost:8080/api
- **Returns**: JSON with app info and features
```json
{
  "message": "Hello World from Python Flask!",
  "version": "1.0.0",
  "built_by": "IBM Bob Secure Skill",
  "features": [...]
}
```

### Health Checks
- **Health**: http://localhost:8080/health
- **Ready**: http://localhost:8080/ready

---

## 🔧 Configuration

### Environment Variables

Create `.env` file from template:
```bash
cp .env.template .env
```

Edit `.env` with your settings:
```bash
# Application
APP_NAME=hello-world-python
APP_VERSION=1.0.0
DEV_PORT=8080

# Concert (Optional)
CONCERT_URL=https://your-instance.concert.saas.ibm.com
CONCERT_API_KEY=your-api-key
CONCERT_INSTANCE_ID=your-instance-id
```

---

## 🐛 Troubleshooting

### Port Already in Use
```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>

# Or use different port
export PORT=8081
python app.py
```

### Module Not Found
```bash
# Ensure virtual environment is activated
source venv/bin/activate

# Reinstall dependencies
pip install -r requirements.txt
```

### Docker Build Fails
```bash
# Clean Docker cache
docker system prune -a

# Rebuild without cache
docker build --no-cache -t hello-world-python:latest .
```

### Kubernetes Pod Not Starting
```bash
# Check pod status
kubectl get pods -l app=hello-world-python

# View pod logs
kubectl logs -l app=hello-world-python

# Describe pod for events
kubectl describe pod -l app=hello-world-python
```

---

## 📊 Testing the "Built by:" Button

1. **Access the app** at http://localhost:8080
2. **Look for the button** labeled "Built by:"
3. **Click the button** to reveal:
   - IBM Bob Secure Skill information
   - List of security features
   - SBOM generation details
   - CI/CD pipeline info
4. **Click again** to hide the information

---

## 🎯 Next Steps

### Local Development
```bash
# Make changes to app.py
# App auto-reloads in debug mode

# Test your changes
curl http://localhost:8080/api
```

### Deploy to Production
```bash
# 1. Push to Gitea
git add .
git commit -m "Update app"
git push origin main

# 2. CI/CD automatically:
#    - Builds Docker image
#    - Generates SBOM
#    - Uploads to Concert (if configured)
#    - Deploys to Kubernetes
```

### View SBOM
```bash
# Generate SBOM locally
./scripts/generate-sbom.sh hello-world-python:latest

# View SBOM
cat sbom/sbom-*.json | jq .

# Upload to Concert
./scripts/generate-sbom.sh hello-world-python:latest --upload
```

---

## 📚 Additional Resources

- [SBOM Generation Guide](../../docs/SBOM_GENERATION_GUIDE.md)
- [Complete Setup Guide](../../docs/COMPLETE_SETUP_GUIDE.md)
- [Security Hardening](../../docs/SECURITY_HARDENING_GUIDE.md)
- [Main README](../../README.md)

---

**Made with ❤️ by IBM Bob Secure Skill** 🤖