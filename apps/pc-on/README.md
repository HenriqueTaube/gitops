# pc-on

Application for remotely turning on the desktop PC via an Arduino.

## Why

The desktop PC runs Windows 11 with Solidworks and AutoCAD — heavy software that stays off when not in use. This app sends a signal to an Arduino connected to the PC, which triggers the power button remotely. Allows starting the machine from anywhere without physically touching it.

## Layout

- `base/`: generic manifests
- `overlays/homelab/`: homelab-specific patches
