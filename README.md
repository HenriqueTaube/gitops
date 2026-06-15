# gitops

> GitOps repository for my homelab Kubernetes cluster — built as a portfolio project to demonstrate production-grade DevOps practices.

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![Flux](https://img.shields.io/badge/Flux_CD-5468FF?logo=flux&logoColor=white)
![Talos](https://img.shields.io/badge/Talos_Linux-FF7300?logo=linux&logoColor=white)
![SOPS](https://img.shields.io/badge/SOPS-000000?logo=mozilla&logoColor=white)
![Kustomize](https://img.shields.io/badge/Kustomize-326CE5?logo=kubernetes&logoColor=white)
![Cilium](https://img.shields.io/badge/Cilium-F8C517?logo=cilium&logoColor=black)

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
       Longhorn           Loki              Orcamentos
       Cilium             CloudNativePG     WireGuard
                                            DuckDNS
                                            Cloudflare Tunnel
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
| [Cilium](https://cilium.io/) | CNI | Started with Flannel but had compatibility problems with the Raspberry Pi nodes. Migrated to Cilium, which handled the mixed AMD64/ARM64 cluster without issues. Also the most widely adopted CNI in the industry. |
| [MetalLB](https://metallb.universe.tf/) | Load balancer | The cluster uses Cilium as the CNI, which includes its own load balancer (CiliumLB). MetalLB was chosen anyway to keep the load balancer as a dedicated, separate component — easier to reason about and troubleshoot independently. Simple Helm installation, almost plug and play for bare-metal. |
| [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/) | External access for Apps| Exposes applications publicly without opening ports on the home network. Creates an outbound connection from the cluster to Cloudflare, making apps accessible at a public domain (e.g. [agente.taubekube.com](https://agente.taubekube.com)) with automatic HTTPS. |
| [Longhorn](https://longhorn.io/) | Persistent storage | Chosen for its built-in snapshot and backup support, agent-per-node architecture, and NFS export capability used for backups. Volumes are automatically distributed and replicated across nodes. Almost plug and play to install — no complex storage backend required. |
| [CloudNativePG](https://cloudnative-pg.io/) | PostgreSQL operator | Used to run the PostgreSQL database for Grafana. Manages PostgreSQL as a Kubernetes-native resource — the database runs in a dedicated pod with its own persistent volume. If the pod is deleted, Kubernetes recreates it automatically with the same data. Configuration is declared in YAML and immutable, which fits the GitOps model. |
| [Grafana + Loki](https://grafana.com/) | Observability | Started running both outside Kubernetes in an Ubuntu Server VM to monitor Proxmox. Migrated into the cluster to keep all workloads managed by GitOps. Grafana is one of the main platform services — dashboard configurations are declared as code in the repository. Loki handles log aggregation for cluster and application logs. |
| [WireGuard](https://www.wireguard.com/) | VPN | Used for remote access to the home network from outside — both personal use and for the company to access Nextcloud and internal apps. Simple, open source, and highly performant. Configuration is based on public/private key pairs, which makes it easy to understand and audit. |
| [DuckDNS](https://www.duckdns.org/) | Dynamic DNS | My ISP provides a real public IP (no CGNAT) but it changes every time the modem reboots. DuckDNS keeps a domain always pointed to the current public IP. A Kubernetes CronJob runs every 5 minutes to update DuckDNS with the latest IP — used as the endpoint for WireGuard so remote clients can always connect regardless of IP changes. |
| [Forgejo](https://forgejo.org/) | Git hosting | Self-hosted Git service used to back up all personal project repositories and collaborate with friends — sharing private repos, `.env` files, and project assets without depending on a third-party platform. Keeping data under my own control is a core motivation for the homelab. |

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
| [Longhorn](infrastructure/longhorn/) | Infrastructure | Distributed persistent storage |
| [CloudNativePG](platform/cloudnativepg/) | Platform | PostgreSQL operator |
| [Grafana](platform/grafana/) | Platform | Metrics dashboards |
| [Loki](platform/loki/) | Platform | Log aggregation |
| [Forgejo](apps/forgejo/) | App | Self-hosted Git service |
| [Orcamentos](apps/orcamentos/) | App | Budget management app |
| [WireGuard](apps/wireguard/) | App | VPN — remote access to home network |
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
