name: Build, Push and Deploy

on:
  push:
    branches: [main, master]
  workflow_dispatch:

jobs:
  build-push-deploy:
    runs-on: ubuntu-latest
    env:
      WORKSPACE_DIR: ${{ github.workspace }}
    steps:
      # Step 1: Checkout code
      - name: Checkout code
        uses: actions/checkout@v4

      # Step 2: Install Docker (if not available)
      - name: Install Docker
        run: |
          if ! command -v docker &> /dev/null; then
            echo "Installing Docker..."
            apt-get update
            apt-get install -y docker.io
          fi
          docker --version

      # Step 3: Set up Docker Buildx
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        with:
          config-inline: |
            [registry."${{ secrets.GIT_REGISTRY }}"]
              http = true
              insecure = true

      # Step 4: Login to Registry
      - name: Login to Gitea Registry
        run: |
          echo "${{ secrets.GIT_TOKEN }}" | docker login ${{ secrets.GIT_REGISTRY }} \
            --username ${{ secrets.GIT_USERNAME }} \
            --password-stdin

      # Step 5: Build and Push Docker Image
      - name: Build and Push
        run: |
          IMAGE_NAME="${{ secrets.GIT_REGISTRY }}/${{ gitea.repository }}"
          docker build -t ${IMAGE_NAME}:latest -t ${IMAGE_NAME}:${{ gitea.sha }} .
          docker push ${IMAGE_NAME}:latest
          docker push ${IMAGE_NAME}:${{ gitea.sha }}
          echo "✓ Image pushed successfully"

      # Step 6: Generate SBOM using Syft container
      - name: Generate SBOM with Syft Container
        run: |
          echo "Using workspace: $WORKSPACE_DIR"
          
          # Run Syft to scan the Docker image and output SBOM files
          docker run --rm \
            --user $(id -u):$(id -g) \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "$WORKSPACE_DIR:/output" \
            -w /output \
            anchore/syft:latest \
            "${{ secrets.GIT_REGISTRY }}/${{ gitea.repository }}:latest" \
            -o spdx-json=/output/sbom.json \
            -o cyclonedx-json=/output/sbom-cyclonedx.json
          
          echo "✓ SBOM generated using containerized Syft"
          echo "Checking for SBOM files in workspace..."
          ls -lh sbom*.json || echo "ERROR: SBOM files not found!"

      # Step 7: Upload SBOM to Concert (Optional)
      - name: Upload SBOM to Concert
        if: secrets.CONCERT_URL != ''
        continue-on-error: true
        env:
          CONCERT_URL: ${{ secrets.CONCERT_URL }}
          CONCERT_API_KEY: ${{ secrets.CONCERT_API_KEY }}
          CONCERT_INSTANCE_ID: ${{ secrets.CONCERT_INSTANCE_ID }}
          CONCERT_APPLICATION_ID: ${{ secrets.CONCERT_APPLICATION_ID }}
        run: |
          pip install requests
          python scripts/upload-sbom-to-concert.py sbom.json --application-id "${CONCERT_APPLICATION_ID}" || echo "⚠ Concert upload skipped"

      # Step 8: Upload SBOM Artifacts (using v3 for Gitea compatibility)
      - name: Upload SBOM Artifacts
        uses: actions/upload-artifact@v3
        with:
          name: sbom-files
          path: |
            sbom.json
            sbom-cyclonedx.json
          retention-days: 90

      # Step 9: Deploy Application
      - name: Deploy Application with kubectl Container
        run: |
          if echo "${{ secrets.KUBECONFIG }}" | base64 -d > /dev/null 2>&1; then
            PLAIN_CONFIG=$(echo "${{ secrets.KUBECONFIG }}" | base64 -d)
          else
            PLAIN_CONFIG="${{ secrets.KUBECONFIG }}"
          fi

          # Substitute image variables in deployment.yaml
          export IMAGE_REGISTRY="${{ secrets.GIT_REGISTRY }}"
          export IMAGE_REPOSITORY="${{ gitea.repository }}"
          export IMAGE_TAG="latest"
          
          echo "Deploying with image: ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}"
          
          # Use envsubst to replace variables, then apply
          envsubst < $WORKSPACE_DIR/k8s/deployment.yaml | docker run --rm -i \
            --entrypoint sh \
            -e KUBECONFIG_DATA="$PLAIN_CONFIG" \
            bitnami/kubectl:latest \
            -c 'echo "$KUBECONFIG_DATA" > /tmp/kubeconfig && kubectl --kubeconfig=/tmp/kubeconfig apply -f -'
          
          docker run --rm \
            --entrypoint sh \
            -e KUBECONFIG_DATA="$PLAIN_CONFIG" \
            bitnami/kubectl:latest \
            -c 'echo "$KUBECONFIG_DATA" > /tmp/kubeconfig && kubectl --kubeconfig=/tmp/kubeconfig rollout status deployment/hello-world-python -n default --timeout=5m'
          
          echo "✓ Application deployed using containerized kubectl"

      # Step 10: Create TLS Certificate
      - name: Create TLS Certificate
        run: |
          if echo "${{ secrets.KUBECONFIG }}" | base64 -d > /dev/null 2>&1; then
            PLAIN_CONFIG=$(echo "${{ secrets.KUBECONFIG }}" | base64 -d)
          else
            PLAIN_CONFIG="${{ secrets.KUBECONFIG }}"
          fi

          # Set ingress host from secret or use default
          INGRESS_HOST="${{ secrets.INGRESS_HOST }}"
          if [ -z "$INGRESS_HOST" ]; then
            INGRESS_HOST="hello-world-python.lab.allwaysbeginner.com"
          fi
          
          echo "Using ingress host: $INGRESS_HOST"

          if docker run --rm --entrypoint sh -e KUBECONFIG_DATA="$PLAIN_CONFIG" bitnami/kubectl:latest -c 'echo "$KUBECONFIG_DATA" > /tmp/kubeconfig && kubectl --kubeconfig=/tmp/kubeconfig get secret hello-world-python-tls -n default' &> /dev/null; then
            echo "✓ TLS secret already exists"
          else
            echo "Creating self-signed TLS certificate for $INGRESS_HOST..."
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
              -keyout tls.key -out tls.crt \
              -subj "/CN=${INGRESS_HOST}/O=IBM Bob Secure Development" \
              2>/dev/null

            TLS_CRT=$(base64 -w 0 < tls.crt)
            TLS_KEY=$(base64 -w 0 < tls.key)

            MANIFEST=$(cat <<EOFCERT
          apiVersion: v1
          kind: Secret
          type: kubernetes.io/tls
          metadata:
            name: hello-world-python-tls
            namespace: default
          data:
            tls.crt: ${TLS_CRT}
            tls.key: ${TLS_KEY}
          EOFCERT
          )

            echo "$MANIFEST" | docker run --rm -i --entrypoint sh -e KUBECONFIG_DATA="$PLAIN_CONFIG" bitnami/kubectl:latest -c 'echo "$KUBECONFIG_DATA" > /tmp/kubeconfig && kubectl --kubeconfig=/tmp/kubeconfig apply -f -'

            rm -f tls.key tls.crt
            echo "✓ TLS certificate created for $INGRESS_HOST using containerized kubectl"
          fi

      # Step 11: Deploy Secure Ingress
      - name: Deploy Secure Ingress
        run: |
          if echo "${{ secrets.KUBECONFIG }}" | base64 -d > /dev/null 2>&1; then
            PLAIN_CONFIG=$(echo "${{ secrets.KUBECONFIG }}" | base64 -d)
          else
            PLAIN_CONFIG="${{ secrets.KUBECONFIG }}"
          fi
          
          # Set ingress host from secret or use default
          export INGRESS_HOST="${{ secrets.INGRESS_HOST }}"
          if [ -z "$INGRESS_HOST" ]; then
            export INGRESS_HOST="hello-world-python.lab.allwaysbeginner.com"
          fi
          
          echo "Deploying ingress for host: $INGRESS_HOST"
          
          # Use envsubst to replace INGRESS_HOST variable
          envsubst < $WORKSPACE_DIR/k8s/ingress-secure.yaml | docker run --rm -i --entrypoint sh -e KUBECONFIG_DATA="$PLAIN_CONFIG" bitnami/kubectl:latest -c 'echo "$KUBECONFIG_DATA" > /tmp/kubeconfig && kubectl --kubeconfig=/tmp/kubeconfig apply -f -'
          
          echo "✓ Ingress deployed for $INGRESS_HOST using containerized kubectl"

      # Step 12: Apply Permissive Network Policy
      - name: Apply Permissive Network Policy
        run: |
          if echo "${{ secrets.KUBECONFIG }}" | base64 -d > /dev/null 2>&1; then
            PLAIN_CONFIG=$(echo "${{ secrets.KUBECONFIG }}" | base64 -d)
          else
            PLAIN_CONFIG="${{ secrets.KUBECONFIG }}"
          fi
          
          cat <<'EOFNETPOL' | docker run --rm -i --entrypoint sh -e KUBECONFIG_DATA="$PLAIN_CONFIG" bitnami/kubectl:latest -c 'echo "$KUBECONFIG_DATA" > /tmp/kubeconfig && kubectl --kubeconfig=/tmp/kubeconfig apply -f -'
            apiVersion: networking.k8s.io/v1
            kind: NetworkPolicy
            metadata:
              name: hello-world-python-netpol
              namespace: default
            spec:
              podSelector:
                matchLabels:
                  app: hello-world-python
              policyTypes:
              - Ingress
              - Egress
              ingress:
              - {}
              egress:
              - {}
          EOFNETPOL
          echo "✓ Permissive network policy applied using containerized kubectl"

      # Step 13: Get Deployment Info
      - name: Get Deployment Info
        run: |
          if echo "${{ secrets.KUBECONFIG }}" | base64 -d > /dev/null 2>&1; then
            PLAIN_CONFIG=$(echo "${{ secrets.KUBECONFIG }}" | base64 -d)
          else
            PLAIN_CONFIG="${{ secrets.KUBECONFIG }}"
          fi
          
          echo "==================================="
          echo "Deployment Information"
          echo "==================================="
          docker run --rm --entrypoint sh -e KUBECONFIG_DATA="$PLAIN_CONFIG" bitnami/kubectl:latest -c 'echo "$KUBECONFIG_DATA" > /tmp/kubeconfig && kubectl --kubeconfig=/tmp/kubeconfig get deployment hello-world-python -n default'
          docker run --rm --entrypoint sh -e KUBECONFIG_DATA="$PLAIN_CONFIG" bitnami/kubectl:latest -c 'echo "$KUBECONFIG_DATA" > /tmp/kubeconfig && kubectl --kubeconfig=/tmp/kubeconfig get pods -l app=hello-world-python -n default'
          docker run --rm --entrypoint sh -e KUBECONFIG_DATA="$PLAIN_CONFIG" bitnami/kubectl:latest -c 'echo "$KUBECONFIG_DATA" > /tmp/kubeconfig && kubectl --kubeconfig=/tmp/kubeconfig get service hello-world-python -n default'
          docker run --rm --entrypoint sh -e KUBECONFIG_DATA="$PLAIN_CONFIG" bitnami/kubectl:latest -c 'echo "$KUBECONFIG_DATA" > /tmp/kubeconfig && kubectl --kubeconfig=/tmp/kubeconfig get ingress hello-world-python-ingress -n default'
          # Get ingress host
          INGRESS_HOST="${{ secrets.INGRESS_HOST }}"
          if [ -z "$INGRESS_HOST" ]; then
            INGRESS_HOST="hello-world-python.lab.allwaysbeginner.com"
          fi
          
          echo ""
          echo "🔒 Secure Access:"
          echo "  URL: https://${INGRESS_HOST}"
          echo ""
          echo "� Add to /etc/hosts on your machine:"
          echo "  <K3S_IP>  ${INGRESS_HOST}"
          echo "==================================="

# Made with Bob
