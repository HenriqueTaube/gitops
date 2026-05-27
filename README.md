# gitops

GitOps repository for my homelab Kubernetes cluster.

## Structure

- `bootstrap/`: Talos bootstrap and image factory notes
- `clusters/`: Flux entrypoints per cluster
- `infrastructure/`: cluster infrastructure components
- `platform/`: shared platform services
- `apps/`: application manifests

## Notes

- This repository uses `base/` and `overlays/homelab/` where possible.
- Secrets are managed with SOPS.
- Flux will reconcile from `clusters/homelab`.
