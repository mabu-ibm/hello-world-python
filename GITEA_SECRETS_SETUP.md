# Gitea Secrets Setup Guide

## 🔐 Required Secrets for CI/CD Pipeline

The CI/CD pipeline requires the following secrets to be configured in your Gitea repository.

**Important**: Gitea doesn't allow secret names starting with `GITEA_`, so we use `GIT_` prefix instead.

## Required Secrets

### 1. GIT_REGISTRY
**Purpose**: Docker registry URL
**Example**: `almabuild.lab.allwaysbeginner.com:3000`
**How to get**: Your Gitea server hostname and port

### 2. GIT_USERNAME
**Purpose**: Gitea username for registry authentication
**Example**: `manfred`
**How to get**: Your Gitea username

### 3. GIT_TOKEN
**Purpose**: Gitea personal access token for registry authentication
**How to get**:
1. Log in to Gitea
2. Go to Settings → Applications → Generate New Token
3. Give it a name (e.g., "CI/CD Pipeline")
4. Select scopes: `write:package` (for pushing images)
5. Click "Generate Token"
6. Copy the token immediately (you won't see it again!)

## Optional Secrets (for Concert Integration)

### 4. CONCERT_URL
**Purpose**: IBM Concert instance URL  
**Example**: `https://12345.us-south-8.concert.saas.ibm.com`  
**How to get**: Your Concert instance URL

### 5. CONCERT_API_KEY
**Purpose**: Concert API key  
**How to get**:
1. Log in to Concert
2. Go to Settings → API Keys
3. Generate new API key
4. Copy the key

### 6. CONCERT_INSTANCE_ID
**Purpose**: Concert instance identifier  
**How to get**: Found in Concert Settings → Instance Information

### 7. CONCERT_APPLICATION_ID
**Purpose**: Application ID in Concert (optional)  
**How to get**: Concert UI → Applications → Select App → Copy ID

## How to Add Secrets in Gitea

### Step 1: Navigate to Repository Settings

```
1. Go to your repository in Gitea
2. Click "Settings" (gear icon)
3. Click "Secrets" in the left sidebar
```

### Step 2: Add Each Secret

```
1. Click "Add Secret"
2. Enter secret name (e.g., GIT_REGISTRY)
3. Enter secret value
4. Click "Add Secret"
5. Repeat for all required secrets
```

### Step 3: Verify Secrets

```
1. Go to Settings → Secrets
2. You should see all secrets listed (values are hidden)
3. Secrets are now available to your workflows
```

## Quick Setup Script

You can also add secrets via Gitea API:

```bash
#!/bin/bash

# Configuration
GITEA_URL="http://almabuild:3000"
GITEA_TOKEN="your-admin-token"
REPO_OWNER="manfred"
REPO_NAME="hello-world-python"

# Function to add secret
add_secret() {
    local secret_name=$1
    local secret_value=$2
    
    curl -X PUT "${GITEA_URL}/api/v1/repos/${REPO_OWNER}/${REPO_NAME}/actions/secrets/${secret_name}" \
        -H "Authorization: token ${GITEA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"data\":\"${secret_value}\"}"
}

# Add required secrets
add_secret "GIT_REGISTRY" "almabuild.lab.allwaysbeginner.com:3000"
add_secret "GIT_USERNAME" "manfred"
add_secret "GIT_TOKEN" "your-gitea-token"

# Add optional Concert secrets
# add_secret "CONCERT_URL" "https://your-instance.concert.saas.ibm.com"
# add_secret "CONCERT_API_KEY" "your-concert-api-key"
# add_secret "CONCERT_INSTANCE_ID" "your-instance-id"
# add_secret "CONCERT_APPLICATION_ID" "your-app-id"

echo "Secrets added successfully!"
```

## Troubleshooting

### Error: "Username required"

**Problem**: GIT_USERNAME secret is missing or empty

**Solution**:
```bash
# Add GIT_USERNAME secret with your Gitea username
# Go to Settings → Secrets → Add Secret
# Name: GIT_USERNAME
# Value: your-username
```

### Error: "Password required"

**Problem**: GIT_TOKEN secret is missing or empty

**Solution**:
```bash
# Generate new token in Gitea
# Settings → Applications → Generate New Token
# Add as GIT_TOKEN secret
```

### Error: "Registry not found"

**Problem**: GIT_REGISTRY secret is incorrect

**Solution**:
```bash
# Verify your Gitea registry URL
# Format: hostname:port (no http://)
# Example: almabuild.lab.allwaysbeginner.com:3000
```

### Error: "Unauthorized"

**Problem**: Token doesn't have correct permissions

**Solution**:
```bash
# Generate new token with these scopes:
# - write:package (for pushing images)
# - read:package (for pulling images)
# - repo (for repository access)
```

## Verification

After adding secrets, trigger a new build:

```bash
# Make a small change and push
echo "# Test" >> README.md
git add README.md
git commit -m "Test CI/CD pipeline"
git push origin main

# Watch the pipeline
# Go to: Repository → Actions
# Check if build succeeds
```

## Security Best Practices

1. **Never commit secrets to git**
   - Secrets are stored securely in Gitea
   - They are not visible in logs
   - They are encrypted at rest

2. **Rotate tokens regularly**
   - Generate new tokens every 90 days
   - Update secrets in Gitea
   - Revoke old tokens

3. **Use minimal permissions**
   - Only grant necessary scopes
   - Use separate tokens for different purposes
   - Don't reuse personal tokens

4. **Monitor secret usage**
   - Check Actions logs for unauthorized access
   - Review token usage in Gitea
   - Revoke compromised tokens immediately

## Summary

### Minimum Required (for basic CI/CD):
- ✅ GIT_REGISTRY
- ✅ GIT_USERNAME
- ✅ GIT_TOKEN

### Optional (for Concert integration):
- ⭕ CONCERT_URL
- ⭕ CONCERT_API_KEY
- ⭕ CONCERT_INSTANCE_ID
- ⭕ CONCERT_APPLICATION_ID

**Note**: SBOM generation works without Concert secrets. Concert upload only happens when CONCERT_URL is configured.

---

**Made with ❤️ by IBM Bob Secure Skill** 🤖