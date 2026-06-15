# longhorn

Distributed persistent storage for the homelab cluster.

## Why

Longhorn provides persistent volumes with automatic replication across nodes. Key reasons for choosing it:

- Built-in snapshot and backup support
- Agent runs per node, managing volumes locally
- Supports NFS export — used for off-cluster backups
- Volumes are automatically distributed and replicated across nodes
- Simple to install, close to plug and play

## Layout

- `base/`: shared Kubernetes resources
- `overlays/homelab/`: homelab entrypoint
- `tests/`: manual test manifests and experiments
