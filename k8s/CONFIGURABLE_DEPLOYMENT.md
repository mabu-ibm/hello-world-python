# Configurable Deployment Guide

This guide explains how to use the configurable deployment.yaml and ingress files with different image registries and hostnames.

## Overview

The deployment and ingress files now use environment variable substitution to make them configurable for different:
- Image registries and repositories
- Ingress hostnames and domains

This allows the same deployment files to work with different Gitea instances, container registries, and domain names.

## Configuration Variables

### Deployment Variables

The deployment.yaml uses three environment variables:

- **`IMAGE_REGISTRY`**: The registry hostname and port (e.g., `almabuild.lab.allwaysbeginner.com:3000`)
- **`IMAGE_REPOSITORY`**: The repository path (e.g., `manfred/hello-world-python`)
- **`IMAGE_TAG`**: The image tag (e.g., `latest`, `v1.0.0`, or git SHA)

### Ingress Variables

The ingress files use one environment variable:

- **`INGRESS_HOST`**: The hostname for ingress access (e.g., `hello-world-python.lab.allwaysbeginner.com`)

## Deployment Template

```yaml
containers:
- name: hello-world-python
  image: ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}
  imagePullPolicy: Always
```

## Usage in Gitea Workflows

### Automatic Configuration

The workflow automatically configures these variables from Gitea secrets and context:

```yaml
- name: Deploy Application
  run: |
    # Substitute image variables in deployment.yaml
    export IMAGE_REGISTRY="${{ secrets.GIT_REGISTRY }}"
    export IMAGE_REPOSITORY="${{ gitea.repository }}"
    export IMAGE_TAG="latest"
    
    echo "Deploying with image: ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}"
    
    # Use envsubst to replace variables, then apply
    envsubst < k8s/deployment.yaml | kubectl apply -f -
## Ingress Configuration Examples

### Basic Ingress Deployment

```bash
# Set ingress hostname
export INGRESS_HOST="myapp.example.com"

# Apply ingress with variable substitution
envsubst < k8s/ingress-secure.yaml | kubectl apply -f -
```

### Different Environments

**Development:**
```bash
export INGRESS_HOST="hello-dev.example.com"
envsubst < k8s/ingress-secure.yaml | kubectl apply -f - -n development
```

**Staging:**
```bash
export INGRESS_HOST="hello-staging.example.com"
envsubst < k8s/ingress-secure.yaml | kubectl apply -f - -n staging
```

**Production:**
```bash
export INGRESS_HOST="hello.example.com"
envsubst < k8s/ingress-secure.yaml | kubectl apply -f - -n production
```

### Custom Domain Examples

**Subdomain:**
```bash
export INGRESS_HOST="api.mycompany.com"
```

**Path-based (requires ingress modification):**
```bash
export INGRESS_HOST="mycompany.com"
# Modify path in ingress.yaml to /api
```

**Wildcard (with wildcard certificate):**
```bash
export INGRESS_HOST="*.apps.mycompany.com"
```

```

### Required Gitea Secrets

Configure these secrets in your Gitea repository:

1. **`GIT_REGISTRY`**: Your registry URL
   - Example: `almabuild.lab.allwaysbeginner.com:3000`
   - Example: `registry.example.com:5000`
   - Example: `docker.io` (for Docker Hub)

2. **`GIT_USERNAME`**: Registry username
3. **`GIT_TOKEN`**: Registry access token/password
4. **`KUBECONFIG`**: Kubernetes configuration for deployment
5. **`INGRESS_HOST`** (Optional): Custom hostname for ingress
   - Example: `myapp.example.com`
   - Example: `hello-world-python.lab.allwaysbeginner.com`
   - Default: `hello-world-python.lab.allwaysbeginner.com` (if not set)

## Manual Deployment

### Using envsubst (Linux/Mac)

```bash
# Set environment variables
export IMAGE_REGISTRY="almabuild.lab.allwaysbeginner.com:3000"
export IMAGE_REPOSITORY="manfred/hello-world-python"
export IMAGE_TAG="latest"

# Apply with variable substitution
envsubst < k8s/deployment.yaml | kubectl apply -f -
```

### Using sed (Alternative)

```bash
# Set variables
REGISTRY="almabuild.lab.allwaysbeginner.com:3000"
REPO="manfred/hello-world-python"
TAG="latest"

# Apply with sed substitution
sed -e "s|\${IMAGE_REGISTRY}|${REGISTRY}|g" \
    -e "s|\${IMAGE_REPOSITORY}|${REPO}|g" \
    -e "s|\${IMAGE_TAG}|${TAG}|g" \
    k8s/deployment.yaml | kubectl apply -f -
```

### Using kubectl with kustomize

Create a `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

images:
- name: ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}
  newName: your-registry.com:5000/your-repo/app
  newTag: v1.0.0
```

## Multi-Environment Setup

### Development Environment

```bash
export IMAGE_REGISTRY="dev-registry.example.com:5000"
export IMAGE_REPOSITORY="dev/hello-world-python"
export IMAGE_TAG="dev-latest"
envsubst < k8s/deployment.yaml | kubectl apply -f - -n development
```

### Production Environment

```bash
export IMAGE_REGISTRY="prod-registry.example.com:5000"
export IMAGE_REPOSITORY="prod/hello-world-python"
export IMAGE_TAG="v1.2.3"
envsubst < k8s/deployment.yaml | kubectl apply -f - -n production
```

## Using Different Registries

### Docker Hub

```bash
export IMAGE_REGISTRY="docker.io"
export IMAGE_REPOSITORY="username/hello-world-python"
export IMAGE_TAG="latest"
```

### GitHub Container Registry

```bash
export IMAGE_REGISTRY="ghcr.io"
export IMAGE_REPOSITORY="username/hello-world-python"
export IMAGE_TAG="main"
```

### Private Harbor Registry

```bash
export IMAGE_REGISTRY="harbor.company.com"
export IMAGE_REPOSITORY="project/hello-world-python"
export IMAGE_TAG="v1.0.0"
```

### Gitea Registry (Different Instance)

```bash
export IMAGE_REGISTRY="gitea.example.com:3000"
export IMAGE_REPOSITORY="team/hello-world-python"
export IMAGE_TAG="latest"
```

## Workflow Customization

### Using Git SHA as Tag

```yaml
export IMAGE_TAG="${{ gitea.sha }}"
```

### Using Branch Name as Tag

```yaml
export IMAGE_TAG="${{ gitea.ref_name }}"
```

### Using Semantic Version

```yaml
export IMAGE_TAG="v1.2.3"
```

### Multiple Tags

```yaml
# Build and push multiple tags
docker build -t ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:latest \
             -t ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${GITEA_SHA} \
             -t ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:v1.0.0 .

# Deploy with specific tag
export IMAGE_TAG="v1.0.0"
envsubst < k8s/deployment.yaml | kubectl apply -f -
```

## Verification

### Check Deployed Image

```bash
kubectl get deployment hello-world-python -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### View Deployment Details

```bash
kubectl describe deployment hello-world-python
```

### Check Pod Image

```bash
kubectl get pods -l app=hello-world-python -o jsonpath='{.items[*].spec.containers[*].image}'
```

## Troubleshooting

### Variable Not Substituted

**Problem**: Variables like `${IMAGE_REGISTRY}` appear literally in deployment

**Solution**: Ensure `envsubst` is installed and variables are exported:
```bash
# Install envsubst (if needed)
apt-get install gettext-base  # Debian/Ubuntu
yum install gettext           # RHEL/CentOS

# Verify variables are set
echo $IMAGE_REGISTRY
echo $IMAGE_REPOSITORY
echo $IMAGE_TAG
```

### Image Pull Error

**Problem**: `ErrImagePull` or `ImagePullBackOff`

**Solutions**:
1. Verify registry URL is correct
2. Check imagePullSecrets are configured
3. Verify image exists in registry
4. Check registry authentication

```bash
# Test registry access
docker login ${IMAGE_REGISTRY}
docker pull ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}
```

### Wrong Image Deployed

**Problem**: Old image version is deployed

**Solution**: Force rollout restart:
```bash
kubectl rollout restart deployment/hello-world-python
kubectl rollout status deployment/hello-world-python
```

## Best Practices

1. **Use Specific Tags**: Avoid `latest` in production, use semantic versions
2. **Verify Before Deploy**: Always echo the final image name before deploying
3. **Test Substitution**: Test `envsubst` output before applying to cluster
4. **Document Registry**: Keep registry URLs documented for team reference
5. **Automate in CI/CD**: Let workflows handle variable substitution automatically
6. **Use Secrets**: Never hardcode registry credentials in workflows
7. **Version Control**: Keep deployment.yaml in version control with variables

## Example Complete Workflow

```yaml
- name: Build and Deploy
  run: |
    # Build image
    IMAGE_REGISTRY="${{ secrets.GIT_REGISTRY }}"
    IMAGE_REPOSITORY="${{ gitea.repository }}"
    IMAGE_TAG="${{ gitea.sha }}"
    
    docker build -t ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG} .
    docker push ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}
    
    # Deploy with substitution
    export IMAGE_REGISTRY IMAGE_REPOSITORY IMAGE_TAG
    echo "Deploying: ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}"
    envsubst < k8s/deployment.yaml | kubectl apply -f -
    
    # Wait for rollout
    kubectl rollout status deployment/hello-world-python --timeout=5m
```

## Additional Resources

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [envsubst Documentation](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html)
- [Gitea Actions Secrets](https://docs.gitea.io/en-us/actions-secrets/)
- [Container Registry Best Practices](https://docs.docker.com/registry/deploying/)

---

**Made with Bob** 🤖