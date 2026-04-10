# How to Push Code to Gitea Repository

## 🚀 Quick Guide: Push Your Code

### Option 1: First Time Setup (New Repository)

```bash
# 1. Navigate to your project
cd project-templates/hello-world-python

# 2. Initialize git (if not already done)
git init
git branch -M main

# 3. Add all files
git add .

# 4. Create initial commit
git commit -m "Initial commit: Hello World Python with SBOM"

# 5. Add Gitea remote
# Replace with your actual Gitea URL and username
git remote add origin http://almabuild:3000/manfred/hello-world-python.git

# 6. Push to Gitea
git push -u origin main
```

### Option 2: Update Existing Repository

```bash
# 1. Navigate to your project
cd project-templates/hello-world-python

# 2. Check current status
git status

# 3. Add changed files
git add .

# 4. Commit changes
git commit -m "Update: Add SBOM generation and NodePort service"

# 5. Push to Gitea
git push origin main
```

---

## 📋 Step-by-Step Guide

### Step 1: Create Repository in Gitea

#### Via Gitea Web UI:
```
1. Go to http://almabuild:3000
2. Click "+" icon → "New Repository"
3. Repository name: hello-world-python
4. Description: Python Flask app with SBOM generation
5. Click "Create Repository"
```

#### Via Gitea API:
```bash
# Set your credentials
GITEA_URL="http://almabuild:3000"
GITEA_TOKEN="your-gitea-token"

# Create repository
curl -X POST "${GITEA_URL}/api/v1/user/repos" \
  -H "Authorization: token ${GITEA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hello-world-python",
    "description": "Python Flask app with SBOM generation",
    "private": false,
    "auto_init": false
  }'
```

### Step 2: Configure Git

```bash
# Set your name and email (if not already set)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Or set per repository
cd project-templates/hello-world-python
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

### Step 3: Initialize Repository

```bash
cd project-templates/hello-world-python

# Initialize git
git init

# Set main as default branch
git branch -M main

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Hello World Python with SBOM

- Flask web application with interactive UI
- SBOM generation with Syft
- Optional Concert integration
- NodePort service for external access
- CI/CD pipeline with Gitea Actions
- Complete documentation"
```

### Step 4: Add Remote and Push

```bash
# Add Gitea as remote
# Format: http://GITEA_HOST:PORT/USERNAME/REPO_NAME.git
git remote add origin http://almabuild:3000/manfred/hello-world-python.git

# Verify remote
git remote -v

# Push to Gitea
git push -u origin main
```

---

## 🔐 Authentication Methods

### Method 1: HTTP with Token (Recommended)

```bash
# Use personal access token in URL
git remote add origin http://YOUR_TOKEN@almabuild:3000/manfred/hello-world-python.git

# Or configure credential helper
git config --global credential.helper store
git push origin main
# Enter username and token when prompted
```

### Method 2: SSH (More Secure)

```bash
# 1. Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "your.email@example.com"

# 2. Add SSH key to Gitea
# Copy public key
cat ~/.ssh/id_ed25519.pub

# Go to Gitea → Settings → SSH/GPG Keys → Add Key
# Paste the public key

# 3. Use SSH URL
git remote add origin git@almabuild:3000:manfred/hello-world-python.git

# 4. Push
git push -u origin main
```

---

## 🔄 Common Git Commands

### Check Status
```bash
git status                    # See what's changed
git log --oneline            # View commit history
git remote -v                # View remote URLs
```

### Stage and Commit
```bash
git add .                    # Add all changes
git add file.py              # Add specific file
git commit -m "message"      # Commit with message
git commit --amend           # Modify last commit
```

### Push and Pull
```bash
git push origin main         # Push to main branch
git pull origin main         # Pull latest changes
git fetch origin             # Fetch without merging
```

### Branch Management
```bash
git branch                   # List branches
git branch feature-name      # Create branch
git checkout feature-name    # Switch branch
git checkout -b feature-name # Create and switch
git merge feature-name       # Merge branch
```

---

## 🐛 Troubleshooting

### Error: "remote origin already exists"

```bash
# Remove existing remote
git remote remove origin

# Add correct remote
git remote add origin http://almabuild:3000/manfred/hello-world-python.git
```

### Error: "Authentication failed"

```bash
# Option 1: Use token in URL
git remote set-url origin http://YOUR_TOKEN@almabuild:3000/manfred/hello-world-python.git

# Option 2: Configure credential helper
git config --global credential.helper store
git push origin main
# Enter username and token
```

### Error: "Repository not found"

```bash
# Verify repository exists in Gitea
# Check URL is correct
git remote -v

# Update remote URL if needed
git remote set-url origin http://almabuild:3000/manfred/hello-world-python.git
```

### Error: "Updates were rejected"

```bash
# Pull latest changes first
git pull origin main --rebase

# Then push
git push origin main
```

### Error: "fatal: not a git repository"

```bash
# Initialize git first
git init
git branch -M main
```

---

## 📝 Complete Example

```bash
# Full workflow from scratch
cd ~/projects

# Copy template
cp -r ~/dev-infrastructure-setup/project-templates/hello-world-python ./my-app
cd my-app

# Initialize git
git init
git branch -M main

# Configure git
git config user.name "Manfred"
git config user.email "manfred@example.com"

# Add files
git add .

# Commit
git commit -m "Initial commit: My Flask app with SBOM"

# Create repository in Gitea (via UI or API)
# Then add remote
git remote add origin http://almabuild:3000/manfred/my-app.git

# Push
git push -u origin main

# Verify in Gitea
open http://almabuild:3000/manfred/my-app
```

---

## 🎯 After Pushing

### 1. Configure Secrets

```bash
# Go to: Repository → Settings → Secrets
# Add:
#   GIT_REGISTRY = almabuild.lab.allwaysbeginner.com:3000
#   GIT_USERNAME = manfred
#   GIT_TOKEN = your-token
```

### 2. Watch CI/CD Pipeline

```bash
# Go to: Repository → Actions
# Watch the build process
# Should see: Build → SBOM Generation → Push to Registry
```

### 3. Verify Deployment

```bash
# Check if pods are running
kubectl get pods -l app=hello-world-python

# Access the app
open http://K3S_IP:30080
```

---

## 📚 Additional Resources

- [Git Documentation](https://git-scm.com/doc)
- [Gitea Documentation](https://docs.gitea.io/)
- [GITEA_SECRETS_SETUP.md](GITEA_SECRETS_SETUP.md) - Configure CI/CD secrets
- [EXTERNAL_ACCESS.md](EXTERNAL_ACCESS.md) - Access deployed app

---

**Made with ❤️ by IBM Bob Secure Skill** 🤖