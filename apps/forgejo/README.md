# forgejo

Self-hosted Git service running inside the cluster.

## Why

Used to back up all personal project repositories and collaborate with friends — sharing private repos, `.env` files, and project assets without depending on a third-party platform. Also serves as a self-hosted container registry: multi-arch images for personal projects are built and stored here, keeping the full image supply chain under my own control. Keeping data and infrastructure self-hosted is a core motivation for the homelab.

## Layout

- `base/`: namespace, deployment, service, and PVC
- `overlays/homelab/`: homelab-specific patches and secrets
