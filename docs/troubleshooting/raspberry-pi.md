# Raspberry Pi 5 — Troubleshooting

Real incidents that happened with the `worker-rasp` node (Raspberry Pi 5 8GB) during cluster setup.

---

## Incident 1: IP conflict with LAN device

### Symptoms

- Longhorn stuck on `worker-rasp`
- DuckDNS CronJob failing
- DNS resolution failures between pods and services on that node

### Root cause

The `worker-rasp` was assigned `192.168.1.153`, which conflicted with a TP-Link device on the local network. The conflict caused cascading network and DNS failures that looked like application or storage problems.

### Fix

Changed the static IP of `worker-rasp` from `192.168.1.153` to `192.168.1.154` and restarted the workers.

### Lesson

**Before investigating storage or application failures on a node, verify there is no IP conflict on the LAN.** Symptoms of an IP conflict can look exactly like Longhorn, DNS, or pod scheduling problems.

---

## Incident 2: Cilium stuck after NIC change

### What happened

Moved `worker-rasp` from the onboard Ethernet to a USB-Ethernet adapter. During the process the node went through multiple IP changes:

- `192.168.1.156` → `192.168.1.90` → `192.168.1.91`

After stabilizing, Cilium was stuck with the old node state.

### Symptoms

- `kubectl get nodes -o wide` showed the node with the new IP (`192.168.1.91`)
- `kubectl get ciliumnodes` still showed `worker-rasp` with the old IP (`192.168.1.156`)
- Cilium pod on the RPi was stuck in the `config` init container
- Logs showed:

```
ipAddr=https://10.96.0.1:443
connect: network is unreachable
```

### What did NOT work

- Deleting the `CiliumNode` object alone
- Restarting the Cilium pod alone
- Changing `k8sServiceHost` via Helm values alone

### Fix

**Step 1** — Delete the stale `CiliumNode`:

```bash
kubectl delete ciliumnode worker-rasp
```

**Step 2** — Patch the Cilium `DaemonSet` and `cilium-operator` deployment to use the real control plane IP instead of `10.96.0.1:443`:

```bash
# Add these env vars to both the cilium DaemonSet and cilium-operator Deployment:
# KUBERNETES_SERVICE_HOST=192.168.1.113
# KUBERNETES_SERVICE_PORT=6443
```

**Step 3** — Restart the network pods:

```bash
kubectl -n kube-system delete pod -l k8s-app=cilium
kubectl -n kube-system delete pod -l name=cilium-operator
kubectl -n kube-system delete pod -l k8s-app=cilium-envoy
```

**Sign the fix worked:** the `config` init container completed with `Exit Code: 0`.

### Diagnostic commands

When a node changes NIC or IP, always validate:

```bash
kubectl get nodes -o wide
kubectl get ciliumnodes
kubectl -n kube-system logs <cilium-pod> -c config
```

If `Node` and `CiliumNode` show different IPs, there is stale state that needs to be cleared.

### Lesson

If Cilium insists on `10.96.0.1:443` and gets stuck at bootstrap after a NIC or IP change, force it to use the real control plane IP. Patching the env vars unblocks the init container.

---

## Incident 3: USB power instability (root cause of incident 2)

### Root cause

The real cause of the NIC instability in incident 2 was **not** the onboard Ethernet of the Raspberry Pi 5.

The root cause was **insufficient USB power**. When the `worker-rasp` was running a USB-Ethernet adapter + SSD + other USB peripherals simultaneously, the Raspberry Pi 5's USB bus did not have enough current. This caused network instability that triggered cascading failures in Talos API, Cilium, and node state.

### Fix

- Reverted to the onboard Ethernet
- Moved the SSD to a **USB hub with external power supply**

### Lesson

On a Raspberry Pi 5, before blaming Talos, Cilium, or the onboard NIC — check USB power budget. A USB-Ethernet adapter + SSD + other accessories can cause instability if the power supply is not sufficient. Use a powered USB hub for storage and heavier peripherals.
