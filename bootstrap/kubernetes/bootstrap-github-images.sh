#!/usr/bin/env bash
# Switch private-registry images to GitHub Container Registry.
set -euo pipefail

# ─── Fill these before running ───────────────────────────────────────────────
GITHUB_USER="henriquetaube"
GITHUB_TOKEN="<YOUR_GITHUB_TOKEN>"
# ─────────────────────────────────────────────────────────────────────────────

echo "Suspending Flux apps reconciliation..."
flux suspend kustomization apps

echo "Creating ghcr.io pull secret for private images..."

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USER \
  --docker-password=$GITHUB_TOKEN \
  -n site-orcamentos

echo "Switching images to ghcr.io..."

kubectl set image deployment/wireguard \
  wireguard=ghcr.io/henriquetaube/wireguard:latest \
  -n wireguard

kubectl set image deployment/toolbox-maintenance-prox \
  toolbox=ghcr.io/henriquetaube/toolbox:latest \
  -n maintenance

kubectl set image deployment/toolbox-maintenance-rasp \
  toolbox=ghcr.io/henriquetaube/toolbox:latest \
  -n maintenance

kubectl set image deployment/site-orcamentos \
  site-orcamentos=ghcr.io/henriquetaube/proposta-taube:latest \
  -n site-orcamentos

kubectl set image deployment/proposta-api \
  proposta-api=ghcr.io/henriquetaube/proposta-api:latest \
  -n site-orcamentos

echo "Adding imagePullSecrets to private deployments..."

kubectl patch deployment/site-orcamentos -n site-orcamentos \
  --patch '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"ghcr-secret"}]}}}}'

kubectl patch deployment/proposta-api -n site-orcamentos \
  --patch '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"ghcr-secret"}]}}}}'

echo "Done. Pods will restart and pull from ghcr.io."
echo ""
echo "Flux apps reconciliation is SUSPENDED."
echo "After Forgejo is healthy, restore volumes from Longhorn UI then run:"
echo "  flux resume kustomization apps"
