# duckdns

Dynamic DNS service that keeps a public domain always pointed to the current home IP. The ISP provides a real public IP (no CGNAT), but it changes every time the modem reboots. Without a fixed domain, WireGuard clients would lose connection after every IP change.

A Kubernetes CronJob runs every 5 minutes, calling the DuckDNS API with an empty `ip=` parameter — DuckDNS detects the current public IP automatically and updates the record. This keeps the WireGuard endpoint always reachable for remote clients and company partners, regardless of IP changes.

## Layout

- `base/`: CronJob definition
- `overlays/homelab/`: homelab-specific patches and secret
