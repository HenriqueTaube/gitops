# agente-ingles

Web application for practicing English conversation with an AI API. Built with a friend and deployed as a real production app — not just a demo. Accessible publicly at [agente.taubekube.com](https://agente.taubekube.com) via Cloudflare Tunnel, with automatic HTTPS and no open ports on the home network.

**Stack:** Next.js · Supabase · OpenAI Whisper (speech-to-text) · GPT-4o · ElevenLabs (text-to-speech)

## Layout

- `base/`: generic Kubernetes manifests
- `overlays/homelab/`: homelab-specific patches and secrets
