# cloudflare

> **Not in use** — this folder is not listed in `clusters/homelab/`, so Flux does not deploy it. Kept for reference.

Cloudflare Tunnel for exposing applications externally.

## Why

Used to expose applications publicly without opening ports on the home network. Cloudflare Tunnel creates an outbound connection from the cluster to Cloudflare, making apps accessible at a public domain with automatic HTTPS — no port forwarding or firewall rules required.

Currently used to expose [agente.taubekube.com](https://agente.taubekube.com) for external access.

## Layout

- `base/`: generic manifests
- `overlays/homelab/`: homelab-specific patches and secrets
