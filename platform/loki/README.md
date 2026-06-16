# loki

Log aggregation for the homelab cluster. Collects logs from Kubernetes workloads and external VMs (Proxmox, Nextcloud, Bitcoin node) via Alloy agents. Logs are stored on NFS and queryable through Grafana dashboards. Exposed via MetalLB LoadBalancer for stable access from both internal cluster services and external VM agents.

## Why

Loki was first deployed alongside Grafana in an Ubuntu Server VM to collect logs from the Proxmox server. Migrated into Kubernetes together with Grafana to keep the full observability stack managed by GitOps.

Loki aggregates logs from cluster components and applications, making them queryable through Grafana dashboards.

## Troubleshooting

See [docs/troubleshooting/loki.md](../../docs/troubleshooting/loki.md) for migration incidents: NodePort endpoint inconsistency across nodes and the move to MetalLB LoadBalancer.

## Layout

- `base/`: namespace, deployment, service, and PVC
- `overlays/homelab/`: homelab-specific config and patches
