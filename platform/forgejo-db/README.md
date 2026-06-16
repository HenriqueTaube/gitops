# forgejo-db

MariaDB database for the Forgejo Git service and container registry. Stores all relational data — repositories, users, issues, and more. MariaDB was chosen over MySQL for collation compatibility: the original Forgejo database from the Ubuntu VM used `utf8mb4_uca1400_as_cs`, which only restores cleanly on MariaDB. Persistent storage is managed by Longhorn, replicated across both cluster nodes.

## Layout

- `base/`: namespace, deployment, service, and PVC
- `overlays/homelab/`: homelab-specific patches
