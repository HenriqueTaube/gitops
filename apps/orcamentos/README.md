# orcamentos

Business proposal generator for the company — used by partners to create and manage quotes. FastAPI backend powered by the Anthropic API to assist with proposal content generation. Supports uploading photos and generating a final formatted document. Container image built with `docker buildx` for ARM64 and stored in the private Forgejo registry.

## Layout

- `base/`: generic manifests
- `overlays/homelab/`: homelab-specific patches and secret
