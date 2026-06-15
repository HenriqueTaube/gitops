# loki

Log aggregation for the homelab cluster.

## Why

Loki was first deployed alongside Grafana in an Ubuntu Server VM to collect logs from the Proxmox server. Migrated into Kubernetes together with Grafana to keep the full observability stack managed by GitOps.

Loki aggregates logs from cluster components and applications, making them queryable through Grafana dashboards.

## Layout

- `base/`: namespace, deployment, service, and PVC
- `overlays/homelab/`: homelab-specific config and patches
