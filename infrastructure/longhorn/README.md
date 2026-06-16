# longhorn

Distributed persistent storage for the homelab cluster.

## Why

Longhorn provides persistent volumes with automatic replication across nodes. Key reasons for choosing it:

- Built-in snapshot and backup support
- Agent runs per node, managing volumes locally
- Supports NFS export — used for off-cluster backups
- Volumes are automatically distributed and replicated across nodes
- Simple to install, close to plug and play

Before adopting Longhorn, persistent storage was handled with plain Kubernetes PVs and PVCs — volume data only existed on the node where it was first created. This meant pods could not be scheduled freely: if Kubernetes placed a pod on a different node, it failed to mount its data. Rather than pinning pods to nodes with `nodeSelector`, the fix was adopting Longhorn and setting its replica count equal to the number of nodes (2 replicas for 2 nodes today). This replicates volume data to every node, letting pods schedule freely, with the extra replicas doubling as backup — and volumes are also backed up to an NFS target for extra safety.

## Layout

- `base/`: shared Kubernetes resources
- `overlays/homelab/`: homelab entrypoint
- `tests/`: manual test manifests and experiments
