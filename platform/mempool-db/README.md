# mempool-db

MariaDB database for the `mempool` block explorer backend. mempool's backend has no Postgres support (MySQL-only schema/queries), so it can't reuse `CloudNativePG` — this is a small, dedicated MariaDB instance instead, same pattern as `forgejo-db`.

## Layout

- `base/`: namespace, secret, deployment, service, and PVC
- `overlays/homelab/`: storage class and size for the PVC

## Note

MariaDB only runs its user/password initialization on the **first boot with an empty data directory** — changing the credentials in `secret.yaml` after that has no effect on the already-running database. If credentials ever need to change, the PVC has to be deleted (safe only if there's no data worth keeping) so it re-initializes from the current secret.
