# Git Workflow Guide

Complete guide for working with this project in Gitea.

---

## 🚀 Quick Start

### First Time Setup

```bash
# 1. Clone the repository
git clone http://almabuild.lab.allwaysbeginner.com:3000/manfred/hello-world-python.git
cd hello-world-python

# 2. Configure Git (if not already done)
git config user.name "Your Name"
git config user.email "your.email@example.com"

# 3. Create a personal access token in Gitea
# Go to: http://almabuild.lab.allwaysbeginner.com:3000/user/settings/applications
# Generate new token with repo permissions
# Save the token securely

# 4. Configure Git credential helper (optional, saves password)
git config credential.helper store
```

---

## 📥 Pull Latest Changes

```bash
# Pull latest changes from main branch
git pull origin main

# Or if you're on a different branch
git pull origin YOUR_BRANCH_NAME
```

---

## 📤 Push Changes

### Method 1: Simple Push (Recommended)

```bash
# 1. Check what changed
git status

# 2. Add all changes
git add .

# 3. Commit with a message
git commit -m "Your commit message here"

# 4. Push to Gitea
git push origin main
```

When prompted for credentials:
- **Username:** manfred
- **Password:** Your personal access token (not your Gitea password)

### Method 2: Using SSH (No Password Needed)

```bash
# 1. Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "your.email@example.com"

# 2. Copy public key
cat ~/.ssh/id_ed25519.pub

# 3. Add to Gitea
# Go to: http://almabuild.lab.allwaysbeginner.com:3000/user/settings/keys
# Click "Add Key" and paste your public key

# 4. Change remote URL to SSH
git remote set-url origin git@almabuild.lab.allwaysbeginner.com:manfred/hello-world-python.git

# 5. Push (no password needed)
git push origin main
```

---

## 🔀 Working with Branches

### Create and Push a New Branch

```bash
# 1. Create and switch to new branch
git checkout -b feature/my-new-feature

# 2. Make your changes
# ... edit files ...

# 3. Commit changes
git add .
git commit -m "Add new feature"

# 4. Push new branch to Gitea
git push origin feature/my-new-feature
```

### Merge Branch to Main

```bash
# 1. Switch to main branch
git checkout main

# 2. Pull latest changes
git pull origin main

# 3. Merge your feature branch
git merge feature/my-new-feature

# 4. Push merged changes
git push origin main

# 5. Delete feature branch (optional)
git branch -d feature/my-new-feature
git push origin --delete feature/my-new-feature
```

---

## 🔄 Common Workflows

### Update Local Repository

```bash
# Fetch all changes from remote
git fetch origin

# See what branches exist
git branch -a

# Pull changes for current branch
git pull origin $(git branch --show-current)
```

### Discard Local Changes

```bash
# Discard all uncommitted changes
git reset --hard HEAD

# Discard changes to specific file
git checkout -- path/to/file

# Pull fresh copy from remote
git fetch origin
git reset --hard origin/main
```

### View History

```bash
# View commit history
git log --oneline

# View changes in last commit
git show

# View changes in specific file
git log -p path/to/file
```

---

## 🎯 Complete Example Workflow

### Scenario: Update app.py and push changes

```bash
# 1. Make sure you're on main branch
git checkout main

# 2. Pull latest changes
git pull origin main

# 3. Edit the file
nano app.py  # or use your preferred editor

# 4. Check what changed
git status
git diff app.py

# 5. Stage the changes
git add app.py

# 6. Commit with descriptive message
git commit -m "Update Flask app to add new endpoint"

# 7. Push to Gitea
git push origin main

# 8. Verify in Gitea web UI
# Go to: http://almabuild.lab.allwaysbeginner.com:3000/manfred/hello-world-python
```

---

## 🔧 Troubleshooting

### Authentication Failed

**Problem:** `Authentication failed` when pushing

**Solution:**
```bash
# Use personal access token, not password
# Generate token at: http://almabuild.lab.allwaysbeginner.com:3000/user/settings/applications

# Or switch to SSH (see Method 2 above)
```

### Push Rejected

**Problem:** `! [rejected] main -> main (fetch first)`

**Solution:**
```bash
# Pull changes first
git pull origin main

# If conflicts, resolve them, then:
git add .
git commit -m "Merge remote changes"
git push origin main
```

### Merge Conflicts

**Problem:** Conflicts when merging or pulling

**Solution:**
```bash
# 1. See conflicted files
git status

# 2. Edit files to resolve conflicts
# Look for markers: <<<<<<<, =======, >>>>>>>

# 3. Mark as resolved
git add path/to/resolved/file

# 4. Complete merge
git commit -m "Resolve merge conflicts"

# 5. Push
git push origin main
```

### Wrong Remote URL

**Problem:** Can't push/pull, wrong repository

**Solution:**
```bash
# Check current remote
git remote -v

# Update remote URL (HTTP)
git remote set-url origin http://almabuild.lab.allwaysbeginner.com:3000/manfred/hello-world-python.git

# Or update to SSH
git remote set-url origin git@almabuild.lab.allwaysbeginner.com:manfred/hello-world-python.git
```

---

## 📋 Git Cheat Sheet

```bash
# Status and Info
git status                    # Show working tree status
git log --oneline            # Show commit history
git diff                     # Show unstaged changes
git diff --staged            # Show staged changes

# Basic Operations
git add .                    # Stage all changes
git add file.txt             # Stage specific file
git commit -m "message"      # Commit staged changes
git push origin main         # Push to remote
git pull origin main         # Pull from remote

# Branching
git branch                   # List branches
git branch feature-name      # Create branch
git checkout branch-name     # Switch branch
git checkout -b new-branch   # Create and switch
git merge branch-name        # Merge branch
git branch -d branch-name    # Delete branch

# Undo Operations
git reset HEAD file.txt      # Unstage file
git checkout -- file.txt     # Discard changes
git reset --hard HEAD        # Discard all changes
git revert commit-hash       # Revert commit

# Remote Operations
git remote -v                # Show remotes
git fetch origin             # Fetch changes
git pull origin main         # Fetch and merge
git push origin main         # Push changes
```

---

## 🎓 Best Practices

1. **Pull before you push** - Always pull latest changes before pushing
2. **Commit often** - Make small, focused commits
3. **Write clear messages** - Describe what and why, not how
4. **Use branches** - Keep main stable, develop in branches
5. **Review before commit** - Use `git diff` to review changes
6. **Test before push** - Ensure code works before pushing

---

## 🔗 Useful Links

- **Gitea Web UI:** http://almabuild.lab.allwaysbeginner.com:3000
- **Repository:** http://almabuild.lab.allwaysbeginner.com:3000/manfred/hello-world-python
- **Settings:** http://almabuild.lab.allwaysbeginner.com:3000/user/settings
- **SSH Keys:** http://almabuild.lab.allwaysbeginner.com:3000/user/settings/keys
- **Access Tokens:** http://almabuild.lab.allwaysbeginner.com:3000/user/settings/applications

---

**Made with ❤️ by IBM Bob Secure Skill** 🤖