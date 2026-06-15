# README Portfolio Task

## Goal
Write the main `README.md` for this gitops repo as a portfolio for a junior DevOps/GitOps job application (English, international).

## Context
- Hardware: AMD64 i5-8400, 24GB RAM running Proxmox — hosts controlplane + 1 worker node
- Second worker: Raspberry Pi 5 8GB RAM
- Also runs on Proxmox (outside k8s): Nextcloud, Bitcoin node (Knots), Pi-hole (DNS/DHCP)
- Repo structure follows the **Flux CD monorepo pattern** with **Kustomize overlays** (base/overlays)

## Agreed README Structure
1. Header + badges + one-line description
2. About — what this is and why you built it
3. Hardware — Proxmox node (i5-8400, 24GB) + RPi 5 (worker)
4. Architecture — ASCII diagram: Hardware → Talos → Flux → Apps
5. Tech stack table — tool | role | why you chose it
6. Repo structure — explained folder by folder (mention Flux monorepo + Kustomize overlays pattern)
7. Key design decisions — SOPS, base/overlay, Flux reconciliation
8. Deployed services — summary table in main README, details in each subfolder README
9. Bootstrap — how to bring up the cluster (brief)
10. Roadmap / what I'm learning next

## Key decisions already made
- Point 8: main README has a summary table linking to subfolder READMEs (apps/, infrastructure/, platform/)
- Each subfolder README explains the service, why it was chosen, and config notes

## Tool interview — answer WHY for each tool
Go one by one. User answers in their own words, Claude helps polish.

### Status
- [x] Talos Linux — answered by user
- [x] Proxmox — answered by user
- [x] Flux CD — answered by user
- [x] Kustomize — answered by user
- [x] SOPS — answered by user
- [x] Cilium — answered by user (added to README)
- [x] MetalLB — answered by user
- [x] Traefik — removed, replaced with Cloudflare Tunnel (answered by user)
- [x] Longhorn — answered by user
- [x] CloudNativePG — answered by user
- [x] Grafana + Loki — answered by user
- [x] Tailscale — removed (not used)
- [x] WireGuard — answered by user
- [x] Cloudflare — covered by Cloudflare Tunnel entry
- [x] DuckDNS — answered by user
- [x] Forgejo — answered by user

## How to resume
1. Open this file
2. Tell Claude: "let's continue the gitops README task, check docs/readme-task.md"
3. Continue the tool interview from where the checklist stopped
4. After all tools are answered, write the main README.md
5. Then update each subfolder README with service details
