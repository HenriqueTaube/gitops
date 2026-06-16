# toolbox

Custom debug container images for navigating the Talos cluster. Since Talos Linux has no SSH or interactive shell, these toolbox pods are the only way to browse node filesystems, edit files, copy data, and run diagnostic commands directly on the host. Two multi-arch images are maintained — one for AMD64 and one for ARM64 (Raspberry Pi) — built with `docker buildx` and stored in the private Forgejo registry.

## Layout

- `base/`: generic maintenance pods
- `overlays/homelab/`: node-specific image and scheduling patches
