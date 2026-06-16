# Raspberry Pi 5 — Troubleshooting

Real incident that happened with the `worker-rasp` node (Raspberry Pi 5 8GB) during cluster setup.

---

## Incident 1: DNS dropping after 5 hours — fixed by upgrading Talos to 1.13.2

### What happened

After 5 hours or up to 2 days of uptime, `worker-rasp` would completely stop responding. The root cause was DNS dropping on the Raspberry Pi node — the Talos DNS resolver became unstable while `worker-prox` stayed healthy with identical configuration.

### What was tried (nothing worked)

- Replaced the SD card
- Tried booting from a USB pendrive (Talos did not boot from it)
- Moved the SSD to an externally-powered USB hub to free up power
- Upgraded the power supply from 3A to 5A
- Rolled back through multiple Talos versions: 1.12.2, 1.12.7, 1.12.8

### Context: Raspberry Pi 4 also tested

Before settling on the Pi 5, two Raspberry Pi 4 boards (4GB and 8GB) were also tested with Talos. Neither was able to run Talos even after bootloader updates. The Raspberry Pi 5 was the only board that worked.

### Fix

Upgrading to **Talos 1.13.2** (the newest version at the time) resolved the DNS instability completely. The problem was a bug in the Talos DNS subsystem that specifically affected the Raspberry Pi 5 node — not a power or hardware issue.

### Lesson

Before suspecting hardware (power supply, SD card, USB devices), check if the issue is version-specific. A Talos bug on ARM64 caused this, and only a version upgrade fixed it.
