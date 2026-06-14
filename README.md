# gitops

> GitOps repository for my homelab Kubernetes cluster — built as a portfolio project to demonstrate production-grade DevOps practices.

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![Flux](https://img.shields.io/badge/Flux_CD-5468FF?logo=flux&logoColor=white)
![Talos](https://img.shields.io/badge/Talos_Linux-FF7300?logo=linux&logoColor=white)
![SOPS](https://img.shields.io/badge/SOPS-000000?logo=mozilla&logoColor=white)
![Kustomize](https://img.shields.io/badge/Kustomize-326CE5?logo=kubernetes&logoColor=white)

---

## About

This repository manages the full lifecycle of my homelab Kubernetes cluster using GitOps principles. Every change to the cluster — from infrastructure to applications — is made through Git. Flux CD watches this repository and automatically reconciles the desired state to the cluster.

I built this project to learn the tools and workflows used in real DevOps and platform engineering teams, starting from scratch with Raspberry Pis and growing into a multi-node, mixed-architecture Kubernetes cluster.

---

## Hardware

| Node | Hardware | Role |
|---|---|---|
| controlplane + worker | AMD64 i5-8400 / 24GB RAM (Proxmox VM) | Kubernetes controlplane + 1 worker |
| worker | Raspberry Pi 5 8GB RAM | Kubernetes worker (ARM64) |

The AMD64 machine also runs additional workloads outside the Kubernetes cluster as Proxmox VMs with Ubuntu Server:

- **Nextcloud** — self-hosted file storage for personal and company use
- **Bitcoin Node** (Knots) — full bitcoin node
- **Networking VM** — Pi-hole (DNS/DHCP) and Unbound

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                       Physical Hardware                      │
│                                                              │
│   ┌──────────────────────────────┐   ┌────────────────────┐  │
│   │   AMD64 i5-8400 / 24GB RAM   │   │  Raspberry Pi 5    │  │
│   │      Proxmox Hypervisor      │   │       8GB RAM      │  │
│   │                              │   │                    │  │
│   │  ┌─────────────┐ ┌────────┐  │   │  ┌──────────────┐  │  │
│   │  │ controlplane│ │ worker │  │   │  │    worker    │  │  │
│   │  └─────────────┘ └────────┘  │   │  └──────────────┘  │  │
│   │                              │   └────────────────────┘  │
│   │  + Nextcloud  + Bitcoin Node │                           │
│   │  + Pi-hole                   │                           │
│   └──────────────────────────────┘                           │
└──────────────────────────────────────────────────────────────┘
                              │
                       Talos Linux
                     (Immutable OS)
                              │
                          Flux CD
                      (GitOps Operator)
                              │
              ┌───────────────┼───────────────┐
              │               │               │
       infrastructure      platform          apps
       ─────────────      ────────          ──────
       MetalLB            Grafana           Forgejo
       Traefik            Loki              Orcamentos
       Longhorn           CloudNativePG     Tailscale
                                            WireGuard
                                            DuckDNS
```

---

## Tech Stack

| Tool | Role | Why I chose it |
|---|---|---|
| [Talos Linux](https://www.talos.dev/) | Kubernetes OS | Immutable, API-driven OS designed exclusively for Kubernetes. No SSH, no shell — everything is declared in YAML. Chosen because it is production-grade and forces a deep understanding of how Kubernetes nodes actually work. |
| [Proxmox](https://www.proxmox.com/) | Hypervisor | Allows running multiple isolated VMs on a single physical machine. Introduced me to VM management, NFS storage, disk provisioning, and SSH. |
| [Flux CD](https://fluxcd.io/) | GitOps operator | Purely CLI and config-file driven — no UI, no extra layer to manage. Everything is declared in YAML and reconciled from Git, which fits naturally into the rest of the stack. Flux is also the most widely adopted GitOps tool in the industry. |
| [Kustomize](https://kustomize.io/) | Config management | Works with pure YAML — no templating language to learn. Base manifests are written directly and overlays handle environment-specific patches, keeping everything readable and straightforward. |
| [SOPS + age](https://github.com/getsops/sops) | Secrets management | Native Flux CD support makes integration straightforward. Only the secret values are encrypted — the YAML structure stays readable in Git. age keys were chosen for their simplicity over PGP. |
| [MetalLB](https://metallb.universe.tf/) | Load balancer | Provides `LoadBalancer` type services on bare-metal clusters where no cloud provider load balancer exists. |
| [Traefik](https://traefik.io/) | Ingress controller | Routes external traffic into the cluster. Chosen for its simple Helm-based installation and good integration with Kubernetes ingress resources. |
| [Longhorn](https://longhorn.io/) | Persistent storage | Distributed block storage for Kubernetes. Provides persistent volumes with replication across nodes. |
| [CloudNativePG](https://cloudnative-pg.io/) | PostgreSQL operator | Manages PostgreSQL clusters as Kubernetes-native resources. More reliable than running a plain postgres pod. |
| [Grafana + Loki](https://grafana.com/) | Observability | Grafana for dashboards, Loki for log aggregation. Provides visibility into cluster and application health. |
| [Tailscale](https://tailscale.com/) | VPN mesh | Secure remote access to cluster services without exposing ports publicly. |
| [WireGuard](https://www.wireguard.com/) | VPN | Lightweight VPN for network-level access to homelab resources. |
| [Cloudflare + DuckDNS](https://www.cloudflare.com/) | DNS | Cloudflare for DNS management and DuckDNS for dynamic DNS updates to my home IP. |
| [Forgejo](https://forgejo.org/) | Git hosting | Self-hosted Git service running inside the cluster. |

---

## Repository Structure

This repository follows the **Flux CD monorepo pattern** with **Kustomize overlays** for environment separation.

```
gitops/
├── bootstrap/
│   └── talos/              # Talos machine configs and Image Factory inputs
├── clusters/
│   └── homelab/            # Flux entrypoint — all reconciliation starts here
│       ├── flux-system/    # Flux bootstrap manifests (auto-generated)
│       ├── infrastructure.yaml
│       ├── platform.yaml
│       └── apps.yaml
├── infrastructure/         # Cluster infrastructure (networking, storage, ingress)
│   ├── metallb/
│   ├── traefik/
│   └── longhorn/
├── platform/               # Shared platform services (databases, observability)
│   ├── cloudnativepg/
│   ├── grafana/
│   ├── loki/
│   └── forgejo-db/
└── apps/                   # Applications running on the cluster
    ├── forgejo/
    ├── orcamentos/
    ├── tailscale/
    ├── wireguard/
    ├── duckdns/
    └── ...
```

Each component follows the same layout:

```
component/
├── base/           # Generic, reusable Kubernetes manifests
└── overlays/
    └── homelab/    # Homelab-specific patches and values
```

Flux applies changes in dependency order: `infrastructure` → `platform` → `apps`.

---

## Key Design Decisions

**Secrets with SOPS + age**
All Kubernetes secrets are encrypted with SOPS before being committed to this repository. Only the age private key (stored locally and never committed) can decrypt them. Flux decrypts secrets automatically at reconciliation time using the `sops-age` Kubernetes secret.

**base/overlays pattern**
Every component has a `base/` with generic manifests and an `overlays/homelab/` with environment-specific patches. This pattern makes it easy to add new environments (e.g. staging) without duplicating manifests.

**Dependency ordering**
Flux Kustomizations use `dependsOn` to enforce reconciliation order. Apps only deploy after infrastructure and platform are healthy, preventing startup failures from missing dependencies.

**Mixed architecture cluster**
The cluster runs on both AMD64 (Proxmox VMs) and ARM64 (Raspberry Pi 5). All workloads use multi-arch container images to run on both node types.

---

## Deployed Services

| Service | Category | Description |
|---|---|---|
| [MetalLB](infrastructure/metallb/) | Infrastructure | Bare-metal load balancer |
| [Traefik](infrastructure/traefik/) | Infrastructure | Ingress controller |
| [Longhorn](infrastructure/longhorn/) | Infrastructure | Distributed persistent storage |
| [CloudNativePG](platform/cloudnativepg/) | Platform | PostgreSQL operator |
| [Grafana](platform/grafana/) | Platform | Metrics dashboards |
| [Loki](platform/loki/) | Platform | Log aggregation |
| [Forgejo](apps/forgejo/) | App | Self-hosted Git service |
| [Orcamentos](apps/orcamentos/) | App | Budget management app |
| [Tailscale](apps/tailscale/) | App | VPN mesh access |
| [WireGuard](apps/wireguard/) | App | VPN |
| [DuckDNS](apps/duckdns/) | App | Dynamic DNS updater |

---

## Bootstrap

> Full bootstrap steps are documented in [bootstrap/talos/README.md](bootstrap/talos/README.md).

High-level steps:

1. Generate Talos machine configs with `talosctl`
2. Apply configs to controlplane and worker nodes
3. Bootstrap the Kubernetes cluster
4. Install Flux CD into the cluster
5. Add the SOPS age private key as a Kubernetes secret
6. Flux reconciles this repository and brings up the full stack

---

## Roadmap

- [ ] Add Prometheus for metrics collection
- [ ] Set up Alertmanager for alerting
- [ ] Implement automated backups for Longhorn volumes
- [ ] Add staging overlay environment
- [ ] Explore Renovate Bot for automated dependency updates
