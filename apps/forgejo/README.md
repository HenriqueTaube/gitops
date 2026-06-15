# forgejo

Self-hosted Git service running inside the cluster.

## Why

Used to back up all personal project repositories and collaborate with friends — sharing private repos, `.env` files, and project assets without depending on a third-party platform. Keeping data under my own control is a core motivation for the homelab.

## Layout

- `base/`: namespace, deployment, service, and PVC
- `overlays/homelab/`: homelab-specific patches and secrets
