# cloudnativepg

PostgreSQL operator for the homelab cluster.

## Why

Used to run the PostgreSQL database for Grafana. CloudNativePG manages PostgreSQL as a Kubernetes-native resource:

- The database runs in a dedicated pod with its own persistent volume
- If the pod is deleted, Kubernetes recreates it automatically with the same data
- Configuration is declared in YAML and immutable, which fits the GitOps model
- More reliable and production-like than running a plain postgres container

## Layout

- `base/`: namespace, storage, secret, and cluster resources
- `overlays/homelab/`: homelab entrypoint
