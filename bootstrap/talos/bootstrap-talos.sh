#!/usr/bin/env bash
# Talos cluster bootstrap runbook.
# Applies configs, bootstraps the cluster, and upgrades workers to the custom
# Image Factory image with iscsi-tools + util-linux-tools (required for Longhorn).
set -euo pipefail

# ─── Fill these before running ───────────────────────────────────────────────
IP_CONTROLPLANE="<IP_CONTROLPLANE>"
IP_WORKER1="<IP_WORKER_PROX>"
IP_WORKER2="<IP_WORKER_RASP>"
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Custom image with iscsi-tools + util-linux-tools (see factory/talos-schematic.yaml)
TALOS_IMAGE="$(cat $SCRIPT_DIR/factory/talos-id-image.json)"

echo "==> Applying controlplane config..."
talosctl apply-config --insecure -n $IP_CONTROLPLANE \
  --file $SCRIPT_DIR/clusterconfig/controlplane.yaml

echo "==> Waiting for controlplane to be healthy..."
talosctl -e $IP_CONTROLPLANE -n $IP_CONTROLPLANE health --wait-timeout 5m

echo "==> Bootstrapping cluster (run once only)..."
talosctl -e $IP_CONTROLPLANE -n $IP_CONTROLPLANE bootstrap

echo "==> Getting kubeconfig..."
talosctl -e $IP_CONTROLPLANE -n $IP_CONTROLPLANE kubeconfig $SCRIPT_DIR/kubeconfig
export KUBECONFIG=$SCRIPT_DIR/kubeconfig

echo "==> Applying worker1 config..."
talosctl apply-config --insecure -n $IP_WORKER1 \
  --file $SCRIPT_DIR/clusterconfig/worker-prox.yaml

echo "==> Waiting for worker1 to be healthy..."
talosctl -e $IP_CONTROLPLANE -n $IP_WORKER1 health --wait-timeout 5m

echo "==> Applying worker2 config..."
talosctl apply-config --insecure -n $IP_WORKER2 \
  --file $SCRIPT_DIR/clusterconfig/worker-rasp.yaml

echo "==> Waiting for worker2 to be healthy..."
talosctl -e $IP_CONTROLPLANE -n $IP_WORKER2 health --wait-timeout 5m

echo "==> Upgrading workers to custom image with Longhorn extensions..."
echo "    Image: $TALOS_IMAGE"

talosctl -e $IP_CONTROLPLANE -n $IP_WORKER1 upgrade \
  --image $TALOS_IMAGE --wait

talosctl -e $IP_CONTROLPLANE -n $IP_WORKER2 upgrade \
  --image $TALOS_IMAGE --wait

echo "==> Validating extensions on workers..."
talosctl -e $IP_CONTROLPLANE -n $IP_WORKER1 get extensions
talosctl -e $IP_CONTROLPLANE -n $IP_WORKER2 get extensions

echo ""
echo "Cluster is ready. Proceed with bootstrap/kubernetes/README.md"
