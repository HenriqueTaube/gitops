# Kubernetes Bootstrap

Runbook to install Flux CD and bring up the full GitOps stack after the Talos cluster is ready.

> Complete the [Talos bootstrap](../talos/README.md) steps first before running these.

## Quick start

Fill in `GITHUB_TOKEN` at the top of the script and run:

```bash
bash bootstrap/kubernetes/bootstrap-flux-pre.sh
```

This creates the `flux-system` namespace, installs the SOPS age secret, and runs `flux bootstrap github`. Flux then reconciles the full stack automatically.

## Image registry

After Flux reconciles, choose one option depending on whether Forgejo is available:

**Option A — Forgejo not available yet (fresh cluster)**

Fill in `GITHUB_TOKEN` at the top and run:

```bash
bash bootstrap/kubernetes/bootstrap-github.sh
```

Switches all private images to `ghcr.io` and suspends Flux reconciliation so it doesn't revert the changes.

While Flux apps are suspended, Longhorn is already running (reconciled by the infrastructure layer). This is the right moment to restore volumes from backup — before Flux resumes and creates empty PVCs for the apps.

**Restoring Longhorn volumes from NFS backup:**

1. Open the Longhorn UI
2. Configure the NFS backup target: `nfs://192.168.1.224:/srv/backup/nfs`
3. Go to **Backup** → find the volume you want to restore
4. Click **Restore** — when prompted, set the PVC name to exactly match what the app expects (e.g. `forgejo-data`, `forgejo-db-data`)
5. Longhorn creates the volume with backup data and a PVC bound to it
6. Repeat for each volume that needs restoring

> The PVC name during restore must match exactly what the app deployment expects. If Flux has already created an empty PVC with that name, delete it first so Longhorn can create it with the restored data.

After all volumes are restored and Forgejo is healthy:

```bash
flux resume kustomization apps
```

Flux sees the PVCs already exist and binds the apps to the restored data.

---

## Step 1 — Create the SOPS age secret

Flux needs the age private key to decrypt secrets during reconciliation. Create the secret **before** bootstrapping Flux so it is ready on the first reconciliation cycle.

The age private key is stored locally at `~/.config/sops/age/keys.txt` — never commit it.

```bash
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=$HOME/.config/sops/age/keys.txt
```

> If the `flux-system` namespace does not exist yet, create it first:
> ```bash
> kubectl create namespace flux-system
> ```

---

## Step 2 — Bootstrap Flux CD

Flux installs itself into the cluster and pushes its manifests to the GitHub repository. A GitHub personal access token is required for Flux to create the deploy key on GitHub.

```bash
export GITHUB_TOKEN=<YOUR_GITHUB_TOKEN>

flux bootstrap github \
  --owner=<GITHUB_USER> \
  --repository=gitops \
  --branch=master \
  --path=clusters/homelab \
  --personal
```

This command:
- Installs Flux controllers into the `flux-system` namespace
- Creates an SSH deploy key on the GitHub repository
- Pushes `clusters/homelab/flux-system/` manifests to the repo
- Flux starts watching the repository and reconciling

---

## Step 3 — Verify Flux is running

```bash
flux check
kubectl get pods -n flux-system
```

Expected: all Flux controllers in `Running` state.

---

## Step 4 — Watch reconciliation

Flux will now reconcile the full stack in order: `infrastructure` → `platform` → `apps`.

```bash
flux get kustomizations --watch
```

Expected: all kustomizations show `Ready: True`.

Check individual resources as they come up:

```bash
kubectl get pods -A
kubectl get helmreleases -A
```

---

## Important: what cannot be recovered from Git

The GitOps repo rebuilds the full stack automatically — but these items must be kept safe outside the repo:

| Item | Location | Notes |
|---|---|---|
| age private key | `~/.config/sops/age/keys.txt` | Required to decrypt all secrets |
| Talos machine configs | `bootstrap/talos/clusterconfig/` (gitignored) | Contain cluster tokens and secrets |
| Longhorn volume data | NFS backup target | Application data not stored in Git |
