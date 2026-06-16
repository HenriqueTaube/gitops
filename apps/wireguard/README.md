# wireguard

VPN for remote access to the home network. Runs plain WireGuard without a web UI, configured manually via config files. Uses `hostNetwork` and `NET_ADMIN` capability for low-level network access. Pinned to a specific node via `nodeAffinity` — VPN clients connect to a fixed IP and port, so the pod must always land on the same node. To add or change a peer, enter the pod via toolbox, edit the WireGuard config, and restart the pod.

## Why

Used for remote access to the home network from outside — both personal use and for the company to access Nextcloud and internal applications. Simple, open source, and highly performant. Configuration is based on public/private key pairs, making it easy to understand and audit.

The WireGuard endpoint uses DuckDNS to stay reachable even when the home public IP changes on modem reboot.

## Layout

- `base/`: generic manifests
- `overlays/homelab/`: homelab-specific patches
