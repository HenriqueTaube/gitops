
  1. OS/node prep — kernel modules, swap off, hostname, DNS (in your case Talos handles all of
  this)
  2. Cluster init — control plane up, workers joined (your talosctl bootstrap)
  3. CNI — network plugin so pods can talk (Talos bundles this)
  4. Secrets — things that never go in Git (your sops-age key, ghcr-secret)
  5. GitOps engine — Flux/ArgoCD bootstrap
  6. Storage — CSI driver up and working (Longhorn via Flux)
  7. Ingress / LoadBalancer — MetalLB, Cloudflare tunnel (via Flux)
  8. Backup verification — confirm Longhorn can reach the NFS backup target

