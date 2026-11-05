# cloudnativepg

> **Not in use** — this folder is not listed in `clusters/homelab/`, so Flux does not deploy it. Kept for reference.

Test PostgreSQL cluster (`pg-lab`, namespace `cloudnativepg-lab`) managed by CloudNativePG.

The PostgreSQL database actually used by Grafana is defined in [platform/grafana/overlays/homelab/cluster.yaml](../grafana/overlays/homelab/cluster.yaml).

## Layout

- `base/`: namespace, storage, secret, and cluster resources
- `overlays/homelab/`: homelab entrypoint
