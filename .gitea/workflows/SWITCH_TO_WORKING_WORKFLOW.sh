#!/bin/bash
# Switch from Native to Docker-in-Docker Workflow
# This fixes the "Docker binary not found" error in containerized runners

set -e

echo "=================================================="
echo "Switching to Docker-in-Docker Workflow"
echo "=================================================="
echo ""

WORKFLOW_DIR=".gitea/workflows"
NATIVE_WORKFLOW="build-push-deploy-native.yaml"
DIND_WORKFLOW="build-push-deploy.yaml"

# Check if we're in the right directory
if [ ! -d "$WORKFLOW_DIR" ]; then
    echo "❌ ERROR: Not in project root directory"
    echo "   Please run this script from: project-templates/hello-world-python/"
    exit 1
fi

# Check if DinD workflow exists
if [ ! -f "$WORKFLOW_DIR/$DIND_WORKFLOW" ]; then
    echo "❌ ERROR: Docker-in-Docker workflow not found"
    echo "   Expected: $WORKFLOW_DIR/$DIND_WORKFLOW"
    exit 1
fi

echo "✓ Found Docker-in-Docker workflow"
echo ""

# Disable native workflow if it exists
if [ -f "$WORKFLOW_DIR/$NATIVE_WORKFLOW" ]; then
    echo "Disabling native workflow..."
    mv "$WORKFLOW_DIR/$NATIVE_WORKFLOW" "$WORKFLOW_DIR/$NATIVE_WORKFLOW.disabled"
    echo "✓ Renamed: $NATIVE_WORKFLOW → $NATIVE_WORKFLOW.disabled"
else
    echo "ℹ Native workflow already disabled or not found"
fi

echo ""
echo "=================================================="
echo "Active Workflows:"
echo "=================================================="
ls -lh "$WORKFLOW_DIR"/*.yaml 2>/dev/null || echo "No active workflows found"

echo ""
echo "=================================================="
echo "Disabled Workflows:"
echo "=================================================="
ls -lh "$WORKFLOW_DIR"/*.disabled 2>/dev/null || echo "No disabled workflows"

echo ""
echo "=================================================="
echo "✅ SUCCESS: Switched to Docker-in-Docker workflow"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Commit the changes:"
echo "     git add .gitea/workflows/"
echo "     git commit -m 'Switch to Docker-in-Docker workflow'"
echo ""
echo "  2. Push to trigger the workflow:"
echo "     git push"
echo ""
echo "  3. Monitor the workflow in Gitea:"
echo "     Repository → Actions → Workflows"
echo ""
echo "The Docker-in-Docker workflow will now work correctly"
echo "in your containerized Gitea runner environment."
echo ""

# Made with Bob
