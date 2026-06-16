# Longhorn — Troubleshooting & Setup Notes

Real incidents and gotchas encountered while installing Longhorn on a Talos Linux cluster.

---

## Incident 1: PodSecurity blocked Longhorn manager from starting

### Symptom

After applying the Longhorn manifests, `longhorn-manager` failed with:

```
violates PodSecurity "baseline:latest"
```

### Root cause

Kubernetes enforces PodSecurity standards at the namespace level. Longhorn requires privileged access, which violates the default `baseline` policy.

### Fix

Label the `longhorn-system` namespace as privileged before or immediately after installation:

```bash
kubectl label namespace longhorn-system \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/audit-version=latest \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/warn-version=latest \
  --overwrite
```

Then restart Longhorn workloads:

```bash
kubectl -n longhorn-system rollout restart daemonset/longhorn-manager
kubectl -n longhorn-system rollout restart deployment/longhorn-driver-deployer
kubectl -n longhorn-system rollout restart deployment/longhorn-ui
```

### Lesson

Always label `longhorn-system` as privileged before applying Longhorn manifests, otherwise the manager fails to start.

---

## Incident 2: Volumes stuck in Degraded — wrong replica count

### Symptom

After creating the first PVCs, volumes showed status `Degraded` even though Longhorn appeared to be running.

### Root cause

The default `longhorn` StorageClass from the official manifest sets `numberOfReplicas: "3"`. The cluster only had 2 worker nodes with Longhorn storage, so the third replica could never be placed — causing volumes to be permanently degraded.

### What did NOT work

Editing the existing StorageClass in place — `StorageClass.parameters` is immutable in Kubernetes.

### Fix

Create a new StorageClass with `numberOfReplicas: "2"` and use it for all PVCs:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-2
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "2880"
  fromBackup: ""
```

Delete the degraded PVCs/pods created with the old class and recreate them using `longhorn-2`. Volumes moved from `Degraded` to `Healthy`.

### Lesson

Set the replica count equal to the number of nodes that have Longhorn storage. With 2 nodes, use 2 replicas. **StorageClass parameters are immutable — create a new class instead of trying to edit the existing one.**

---

## Incident 3: Longhorn requires Talos system extensions — not apply-config

### What happened

After installing Longhorn manifests, volumes failed to attach. The Longhorn manager could not find the required host-level binaries (`iscsiadm`, `blkid`).

### Root cause

Talos Linux does not allow installing packages on the host. Host-level tools must be baked into the Talos node image via `systemExtensions` in a custom schematic — not applied via `talosctl apply-config`.

### Fix

**Step 1** — Create a schematic with the required extensions:

```yaml
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
```

**Step 2** — Submit the schematic to the Talos Image Factory and get a `schematic id`.

**Step 3** — Upgrade both worker nodes to the custom image:

```bash
talosctl -e 192.168.1.113 -n <worker-ip> upgrade \
  --image factory.talos.dev/metal-installer/<SCHEMATIC_ID>:<talos-version> \
  --wait
```

**Step 4** — Validate extensions and `iscsid` are running after upgrade:

```bash
talosctl -e 192.168.1.113 -n <worker-ip> get extensions
talosctl -e 192.168.1.113 -n <worker-ip> service iscsid
```

### Note

During upgrade, `connection reset by peer` may appear — this is expected during the node reboot. Validate the node after it comes back online.

### Lesson

On Talos, system-level dependencies like `iscsi-tools` and `util-linux-tools` cannot be installed via config patches. They require a custom node image built through the Image Factory.

---

## Incident 4: Volumes fail to mount — missing kubelet extraMounts

### Symptom

Even after the extensions were installed, some volumes failed to attach or mount correctly on the workers.

### Root cause

On Talos, the `kubelet` runs inside a container. For Longhorn to propagate mounts correctly between the host and the kubelet, `extraMounts` with `rshared` propagation must be configured explicitly.

### Fix

Add the following to `machine.kubelet` in both worker node configs (`worker-prox.yaml` and `worker-rasp.yaml`):

```yaml
machine:
  kubelet:
    extraMounts:
      - destination: /var/lib/longhorn
        type: bind
        source: /var/lib/longhorn
        options:
          - bind
          - rshared
          - rw
```

Apply the patch and reboot each worker:

```bash
talosctl -e 192.168.1.113 -n <worker-ip> apply-config --file worker-<name>.yaml
```

### Lesson

Without `extraMounts` and `rshared`, Longhorn installs without errors but volume mount propagation silently fails. This is a Talos-specific requirement not mentioned in the standard Longhorn installation guide.
