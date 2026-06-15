# grafana

Metrics and log dashboards for the homelab cluster.

## Why

Grafana was first deployed in an Ubuntu Server VM to monitor the Proxmox hypervisor. As the cluster grew, it was migrated into Kubernetes to keep all workloads managed by GitOps.

Grafana is one of the main platform services — dashboard configurations are declared as code in this repository. It connects to Loki for log visualization and to CloudNativePG for its database backend.

## Layout

- `base/`: namespaces, deployment, service, and base secret
- `overlays/homelab/`: homelab-specific database and service resources
