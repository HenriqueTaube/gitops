# Forgejo — Migration Troubleshooting

Full migration journey: Ubuntu Server VM → Kubernetes cluster, with storage evolving from local-path → NFS → Longhorn.

---

## Migration Overview

Forgejo was originally running on an Ubuntu Server VM with:
- App data in `/var/lib/forgejo/data`
- MySQL database at `127.0.0.1:3306`
- Config at `/etc/forgejo/app.ini`

The migration happened in stages, each with its own incidents.

---

## Stage 1: VM → Kubernetes (local-path storage)

### Key gotcha: use the official image, not the self-hosted registry

During migration, the Forgejo container image was intentionally pulled from `codeberg.org/forgejo/forgejo:14.0` instead of the self-hosted Forgejo registry. This avoids a dependency loop: if the only registry is the same Forgejo instance being migrated, it may be unavailable during the migration window — you can't pull from a service you haven't brought up yet.

### Incident: nested data directory after tar restore

When restoring the app data from the VM into the PVC, the layout ended up duplicated:

```
/data/data/data/forgejo-repositories
```

instead of the expected:

```
/data/data/forgejo-repositories
```

**Root cause:** the tar backup included the parent path, so extracting it into `/data` added an extra level.

**Fix:** updated `app.ini` to point to the real paths:

```ini
WORK_PATH     = /data
APP_DATA_PATH = /data/data
ROOT          = /data/data/data/forgejo-repositories
ROOT_PATH     = /data/log
```

Not ideal, but functional. The correct long-term fix is to reorganize the NFS content with Forgejo stopped to collapse the extra `data` level.

### Incident: MariaDB collation breaks restore on MySQL 8

The VM used MariaDB, which created tables with collation `utf8mb4_uca1400_as_cs`. When restoring the dump to a `mysql:8` container in the cluster, the restore failed — MySQL 8 does not recognize this collation.

**Fix:** switch the cluster database from `mysql:8` to `mariadb:11.6`. The dump restored cleanly.

### Lesson

**Always check the source database engine and collation before planning the restore target.** A MariaDB dump is not always compatible with MySQL.

---

## Stage 2: local-path → NFS

At this point, Longhorn was not yet installed in the cluster. NFS was used as the PVC storage backend — the goal was to move Forgejo's persistent data off local-path storage and onto NFS-backed PVCs, which also served as the backup location.

### Migration flow

1. Copy app data from the local PVC to the NFS path: `/srv/backup/nfs/forgejo`
2. Create new PVCs backed by NFS (app data and MySQL)
3. Dump the MariaDB database with `mariadb-dump`
4. Import the dump into the new MariaDB instance pointing to the NFS PVC
5. Update the `forgejo-app-ini` Secret with the new paths
6. Restart the Forgejo deployment

---

## Stage 3: NFS → Longhorn

### Migration flow

Used a temporary pod to copy data between PVCs without downtime risk:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: forgejo-data-copy
  namespace: forgejo
spec:
  restartPolicy: Never
  containers:
    - name: copy
      image: alpine:3.22
      command: ["/bin/sh", "-c", "sleep 36000"]
      volumeMounts:
        - name: old-data
          mountPath: /data
        - name: new-data
          mountPath: /longhorn
  volumes:
    - name: old-data
      persistentVolumeClaim:
        claimName: forgejo-data
    - name: new-data
      persistentVolumeClaim:
        claimName: forgejo-longhorn
```

```bash
kubectl apply -f longhorn-migrator/pod-for-copy.yaml
kubectl -n forgejo exec -it forgejo-data-copy -- sh
cp -a /data/. /longhorn/
```

### Incident: Multi-Attach error blocked Forgejo from starting

After the copy, the main Forgejo deployment failed to start with a `Multi-Attach` error on the PVC.

**Root cause:** the temporary copy pod (`forgejo-data-copy`) was still running and holding the `ReadWriteOnce` PVC, preventing the main deployment from attaching it.

**Fix:** delete the copy pod after the data transfer is complete:

```bash
kubectl -n forgejo delete pod forgejo-data-copy
```

### Incident: Longhorn replica count needed adjustment mid-migration

During the NFS → Longhorn migration, the Longhorn StorageClass still had 3 replicas configured. The new PVCs became `Degraded`.

**Fix:** use the custom `longhorn-2` StorageClass (2 replicas) for all Forgejo PVCs. See [longhorn.md](longhorn.md) for details.

---
