# mempool

Self-hosted [mempool](https://github.com/mempool/mempool) block explorer — frontend + backend, running in the cluster.

## Why

Consulting the blockchain (checking addresses, transactions, fees) through mempool.space's public site means a third party can correlate those lookups — and the wallet activity behind them — with my IP. Self-hosting against my own Bitcoin node keeps that private: nothing about what I look up ever leaves my own infrastructure.

`bitcoind` (Bitcoin Knots) and `electrs` run outside Kubernetes, on a Proxmox Ubuntu VM — that's mempool's normal topology, nothing about the node needs to move into the cluster. The backend reaches them through a `Service`/`Endpoints` pair with no selector, pointing at the VM's LAN IP, so the connection details stay in one place instead of hardcoded across manifests. Backend mode is `electrum` (talks to `electrs` over the plain Electrum TCP protocol, no TLS) rather than `esplora`, since this is upstream `romanz/electrs`, not the `mempool/electrs` fork.

Images are built from a Forgejo mirror of the upstream repo rather than pulled from Docker Hub, keeping the full image supply chain self-hosted — same motivation as the Forgejo registry itself.

## Layout

- `base/`: namespace, `Service`/`Endpoints` for the external Knots VM, backend secret/deployment/service, frontend deployment/service
- `overlays/homelab/`: LoadBalancer IP for the frontend, node pinning to `worker-rasp` (images are currently `arm64`-only)

## Database

Uses `platform/mempool-db` (MariaDB) — mempool's backend has no Postgres support, so it can't reuse `CloudNativePG`.
