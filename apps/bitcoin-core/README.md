# bitcoin-core

[Bitcoin Core](https://github.com/bitcoin/bitcoin) v29 full node (mainnet, unpruned) running inside the cluster.

> **This node does not serve as a peer for other users.** It accepts **no inbound connections from the internet**: no LoadBalancer IP, no router port forward for `8333`. It only opens **outbound** connections (~10 peers by default), downloads and validates the full chain, and relays blocks/transactions only to those peers it connected to. Other nodes on the internet can't connect to it or sync from it.

## Why

Runs a Bitcoin Core node next to the existing Knots node (Proxmox VM, used by `apps/mempool`), managed by GitOps like the rest of the homelab. Stays on the v29 line (still maintained, latest `29.5`) and keeps the 83-byte `datacarriersize` OP_RETURN relay limit.

## Image

`bitcoin/bitcoin:29.5` from Docker Hub, built from [willcl-ark/bitcoin-core-docker](https://github.com/willcl-ark/bitcoin-core-docker) using the release binaries from bitcoincore.org (GPG-verified at build time). The Debian tag is multi-arch (`amd64`, `arm64`, `arm/v7`), but the pod is pinned to `worker-prox` anyway because of storage (see below). The `-alpine` tags are `amd64`-only, so don't use them.

## Storage

The chain lives on the **2TB SSD on `worker-prox`** (Talos mount `/var/mnt/bitcoin`, added as a Longhorn disk with the tag `bitcoin`), through the `longhorn-bitcoin` StorageClass (`overlays/homelab/storageclass.yaml`, owned by this app like `platform/cloudnativepg` owns its class):

- `numberOfReplicas: "1"` + `diskSelector: "bitcoin"`: one copy, only on that SSD. The other Longhorn disks (500GB HDD, 120GB Pi SSD) are too small.
- `dataLocality: strict-local`: the data path stays local to the node, so there's no network replica hop (faster IBD).
- `reclaimPolicy: Retain`: deleting the PVC (or a Flux prune) keeps the Longhorn volume, so the chain isn't lost.
- The pod has `nodeSelector: kubernetes.io/hostname: worker-prox`. It **never** runs on `worker-rasp`. If worker-prox is down, bitcoin-core is down. That's accepted: the chain can always be re-downloaded and there's no backup.

The image entrypoint runs as root, runs `chown -R` on the datadir and drops to `gosu`. The deployment bypasses it (`command: bitcoind`) and runs directly as UID/GID `101` (the image's `bitcoin` user) with a hardened `securityContext`. `fsGroupChangePolicy: OnRootMismatch` stops the kubelet from running `chown` over the 1300Gi volume on every start.

## Layout

- `base/`: namespace, `bitcoin.conf` ConfigMap, Deployment, ClusterIP Service (RPC `8332`, P2P `8333`), PVC (RWO, 1300Gi)
- `overlays/homelab/`: `longhorn-bitcoin` StorageClass + PVC patch to use it, `worker-prox` nodeSelector, securityContext, volumes, SOPS secret with the `rpcauth` lines

## RPC access

RPC is only reachable inside the cluster at `bitcoin-core.bitcoin-core.svc:8332` (`rpcallowip=10.0.0.0/8`). Credentials use `rpcauth` (salted hash, no plaintext password in the config):

```bash
# from a checkout of bitcoin/bitcoin at v29.5
python3 share/rpcauth/rpcauth.py mempool
# put the "rpcauth=..." line into overlays/homelab/secret.yaml, keep the password for the client
sops --encrypt --in-place apps/bitcoin-core/overlays/homelab/secret.yaml
```

`bitcoin-cli` inside the pod uses the cookie file and needs no password:

```bash
kubectl -n bitcoin-core exec deploy/bitcoin-core -- bitcoin-cli -datadir=/home/bitcoin/.bitcoin getblockchaininfo
```

## Operations

- **Config changes** (`configmap.yaml`) don't restart the pod. Run `kubectl -n bitcoin-core rollout restart deploy/bitcoin-core` after Flux applies them.
- **Shutdown:** `terminationGracePeriodSeconds: 300` gives bitcoind time to flush `dbcache`. A SIGKILL mid-flush means a long reindex.
- **Disk:** the mainnet chain is ~800 GB and grows ~80–100 GB/year. The PVC is 1300Gi on a 2TB SSD (~1.8TiB usable). That's the largest size Longhorn will schedule, because it keeps 25% of the disk free. The volume is expandable: increase `storage` in `base/pvc.yaml`.
- **Initial sync (IBD)** takes days. It runs with `dbcache=3000` and memory `4Gi` request / `5Gi` limit (worker-prox has 11.3 GiB). **When `getblockchaininfo` shows `"initialblockdownload": false`**, drop to `dbcache=1000` in `configmap.yaml` and `2Gi` / `4Gi` in `deployment.yaml` to give the RAM back, then push.
- **Logs:** stdout only (`printtoconsole=1`, `nodebuglogfile=1`), collected by Alloy into Loki. No `debug.log` on the volume.

## Network access

| Who | How | LAN IP needed? |
|---|---|---|
| Internet peers (inbound P2P) | — (blocked by design, see top) | No |
| Outbound P2P to the Bitcoin network | Pod egress through the node | No |
| `bitcoin-cli` / admin | `kubectl exec` | No |
| Electrs / mempool **inside the cluster** | Service `bitcoin-core.bitcoin-core.svc`: RPC `8332` + P2P `8333` (electrs fetches blocks over P2P) | No |
| Wallets (Sparrow, Electrum…) | Through **electrs** (`50001`/`50002`), never straight to bitcoind | **Yes, for electrs**: a MetalLB IP on the electrs Service, not on this one |

`listen=1` stays on (the default) so in-cluster electrs can use P2P `8333`. Inbound from the internet is blocked only because nothing exposes the port outside the cluster. **Don't add a LoadBalancer or port forward for `8333` unless you want the node to start serving peers.**
