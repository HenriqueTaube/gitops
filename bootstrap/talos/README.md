# Talos Bootstrap

Talos bootstrap files and runbook for the homelab cluster.

## Contents

- `clusterconfig/`: generated Talos machine configs (gitignored — contains cluster secrets, keep locally)
- `factory/`: Talos Image Factory schematic and custom image reference

---

## Node IPs

| Node | IP |
|---|---|
| controlplane-proxmox | `<IP_CONTROLPLANE>` |
| worker-prox | `<IP_WORKER_PROX>` |
| worker-rasp | `<IP_WORKER_RASP>` |

---

## Step 1 — Apply machine configs

Run from the `bootstrap/talos/` directory. Use `--insecure` on first apply (nodes don't have certificates yet):

```bash
talosctl apply-config --insecure -n <IP_CONTROLPLANE> --file clusterconfig/controlplane.yaml
talosctl apply-config --insecure -n <IP_WORKER_PROX> --file clusterconfig/worker-prox.yaml
talosctl apply-config --insecure -n <IP_WORKER_RASP>  --file clusterconfig/worker-rasp.yaml
```

## Step 2 — Bootstrap the cluster

Run **once only** on the controlplane — bootstrapping twice will corrupt the cluster:

```bash
talosctl -e <IP_CONTROLPLANE> -n <IP_CONTROLPLANE> bootstrap
```

## Step 3 — Get kubeconfig

```bash
talosctl -e <IP_CONTROLPLANE> -n <IP_CONTROLPLANE> kubeconfig ./kubeconfig
export KUBECONFIG=./kubeconfig
```

## Step 4 — Check cluster health

```bash
# Check Talos health on each node
talosctl -e <IP_CONTROLPLANE> -n <IP_CONTROLPLANE> health
talosctl -e <IP_CONTROLPLANE> -n <IP_WORKER_PROX> health
talosctl -e <IP_CONTROLPLANE> -n <IP_WORKER_RASP>  health

# Check Kubernetes nodes are Ready
kubectl get nodes -o wide
```

## Step 5 — Upgrade workers to the custom image

**Important:** Longhorn requires `iscsi-tools` and `util-linux-tools` baked into the node image. The workers **must** run the custom image from the Image Factory — the default Talos image will not work with Longhorn.

The schematic is defined in `factory/talos-schematic.yaml`. The resulting image is:

```
factory.talos.dev/metal-installer/613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245:v1.12.6
```

Upgrade both workers (the same schematic works for both AMD64 and ARM64):

```bash
talosctl -e <IP_CONTROLPLANE> -n <IP_WORKER_PROX> upgrade \
  --image factory.talos.dev/metal-installer/613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245:v1.12.6 \
  --wait

talosctl -e <IP_CONTROLPLANE> -n <IP_WORKER_RASP> upgrade \
  --image factory.talos.dev/metal-installer/613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245:v1.12.6 \
  --wait
```

> `connection reset by peer` during upgrade is expected — the node reboots. Validate after it comes back.

Validate extensions and `iscsid` are active on both workers:

```bash
talosctl -e <IP_CONTROLPLANE> -n <IP_WORKER_PROX> get extensions
talosctl -e <IP_CONTROLPLANE> -n <IP_WORKER_RASP>  get extensions

talosctl -e <IP_CONTROLPLANE> -n <IP_WORKER_PROX> service iscsid
talosctl -e <IP_CONTROLPLANE> -n <IP_WORKER_RASP>  service iscsid
```

Expected: `siderolabs/iscsi-tools`, `siderolabs/util-linux-tools` listed, `iscsid` running on both nodes.

