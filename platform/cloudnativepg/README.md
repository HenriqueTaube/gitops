# cloudnativepg

PostgreSQL operator for the homelab cluster.

## Why

Used to run the PostgreSQL database for Grafana. CloudNativePG manages PostgreSQL as a Kubernetes-native resource:

- The database runs in a dedicated pod with its own persistent volume
- If the pod is deleted, Kubernetes recreates it automatically with the same data
- Configuration is declared in YAML and immutable, which fits the GitOps model
- More reliable and production-like than running a plain postgres container

Grafana originally ran with a SQLite database stored on an NFS volume. This caused intermittent slowness — SQLite over NFS is unreliable under load — and the PVC was locked to a single node, preventing the pod from scheduling freely. The fix was migrating to PostgreSQL managed by CloudNativePG. Before cutting over, a test Grafana instance was spun up alongside the original to validate the migration: dashboards and datasources were recreated and verified, and only then was the old SQLite Grafana decommissioned. CloudNativePG runs 2 PostgreSQL replicas across the 2 nodes, so the database pod schedules freely and the replication provides redundancy.

## Layout

- `base/`: namespace, storage, secret, and cluster resources
- `overlays/homelab/`: homelab entrypoint
