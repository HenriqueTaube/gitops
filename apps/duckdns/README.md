# duckdns

Dynamic DNS updater running as a Kubernetes CronJob.

## Why

The ISP provides a real public IP (no CGNAT) but it changes every time the modem reboots. DuckDNS keeps a domain always pointed to the current public IP.

A CronJob runs every 5 minutes to fetch the current public IP and update the DuckDNS record. This domain is used as the WireGuard endpoint so remote clients can always connect regardless of IP changes.

## Layout

- `base/`: CronJob definition
- `overlays/homelab/`: homelab-specific patches and secret
