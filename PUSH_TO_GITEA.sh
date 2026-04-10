#!/bin/bash
################################################################################
# Push Hello World Python App to Gitea
# Purpose: Automate repository creation and push to Gitea
# Usage: ./PUSH_TO_GITEA.sh
################################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
GITEA_URL="http://almabuild:3000"
REPO_NAME="hello-world-python"

log_info "Push Hello World Python App to Gitea"
echo ""

# Step 1: Get Gitea credentials
read -p "Enter your Gitea username: " GITEA_USER
read -sp "Enter your Gitea password: " GITEA_PASS
echo ""

# Step 2: Check if repository exists
log_info "Checking if repository exists..."
REPO_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
  -u "${GITEA_USER}:${GITEA_PASS}" \
  "${GITEA_URL}/api/v1/repos/${GITEA_USER}/${REPO_NAME}")

if [ "$REPO_EXISTS" == "200" ]; then
    log_warn "Repository ${REPO_NAME} already exists"
    read -p "Do you want to push to existing repository? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        log_info "Aborted"
        exit 0
    fi
else
    # Step 3: Create repository
    log_info "Creating repository ${REPO_NAME}..."
    CREATE_RESPONSE=$(curl -s -X POST \
      -u "${GITEA_USER}:${GITEA_PASS}" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"${REPO_NAME}\",
        \"description\": \"Hello World Python Flask application with CI/CD\",
        \"private\": false,
        \"auto_init\": false
      }" \
      "${GITEA_URL}/api/v1/user/repos")
    
    if echo "$CREATE_RESPONSE" | grep -q "\"name\":\"${REPO_NAME}\""; then
        log_info "✓ Repository created successfully"
    else
        log_error "Failed to create repository"
        echo "$CREATE_RESPONSE"
        exit 1
    fi
fi

# Step 4: Initialize git if needed
if [ ! -d ".git" ]; then
    log_info "Initializing git repository..."
    git init
    git branch -M main
fi

# Step 5: Add files
log_info "Adding files..."
git add .

# Step 6: Commit
log_info "Creating commit..."
git commit -m "Initial commit: Hello World Python Flask app

Features:
- Flask web application with JSON API
- Health check endpoints
- Docker containerization
- Gitea Actions CI/CD pipeline
- Automated testing and building
- Push to Gitea registry

Created with IBM Bob AI" || log_warn "No changes to commit"

# Step 7: Add remote
REMOTE_URL="${GITEA_URL}/${GITEA_USER}/${REPO_NAME}.git"
if git remote | grep -q "origin"; then
    log_info "Updating remote origin..."
    git remote set-url origin "$REMOTE_URL"
else
    log_info "Adding remote origin..."
    git remote add origin "$REMOTE_URL"
fi

# Step 8: Push
log_info "Pushing to Gitea..."
git push -u origin main

# Step 9: Configure secrets
log_info ""
log_warn "IMPORTANT: Configure repository secrets for CI/CD"
log_info "1. Go to: ${GITEA_URL}/${GITEA_USER}/${REPO_NAME}/settings/secrets"
log_info "2. Add secret: GITEA_USERNAME = ${GITEA_USER}"
log_info "3. Add secret: GITEA_PASSWORD = <your-password-or-token>"
echo ""

# Step 10: Success
log_info "============================================"
log_info "Successfully pushed to Gitea!"
log_info "============================================"
log_info "Repository: ${GITEA_URL}/${GITEA_USER}/${REPO_NAME}"
log_info "Actions: ${GITEA_URL}/${GITEA_USER}/${REPO_NAME}/actions"
log_info ""
log_info "Next steps:"
log_info "1. Configure secrets (see above)"
log_info "2. Make a change and push to trigger CI/CD"
log_info "3. Watch the build in Actions tab"
log_info "4. Deploy to K3s (see README.md)"
log_info "============================================"

# Made with Bob
