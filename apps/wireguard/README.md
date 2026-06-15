# wireguard

VPN for remote access to the home network.

## Why

Used for remote access to the home network from outside — both personal use and for the company to access Nextcloud and internal applications. Simple, open source, and highly performant. Configuration is based on public/private key pairs, making it easy to understand and audit.

The WireGuard endpoint uses DuckDNS to stay reachable even when the home public IP changes on modem reboot.

## Layout

- `base/`: generic manifests
- `overlays/homelab/`: homelab-specific patches
