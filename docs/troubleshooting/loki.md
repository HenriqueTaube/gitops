# Loki — Migration Troubleshooting

Migration from an Ubuntu Server VM into the Kubernetes cluster.

---

## Migration Overview

Loki was originally running outside the cluster on an Ubuntu Server VM alongside Grafana. The goal was to move it into Kubernetes to keep all workloads managed by GitOps.

Storage was kept on NFS during the migration (`192.168.1.224:/srv/backup/nfs/loki`) to avoid losing existing log data.

---

## Incident 1: External VMs couldn't reach Loki via NodePort on worker-rasp

### Setup

Loki was deployed with a `NodePort` service on port `31010`. External VMs (like the Bitcoin node) use `alloy` to push logs to Loki.

The Loki pod was scheduled on `worker-rasp`.

### Symptom

The Alloy agent on external VMs could not push logs when configured to use the `worker-rasp` IP:

```
192.168.1.153:31010 → connection refused
```

### Root cause

Even though the pod was running on `worker-rasp`, the `NodePort` on that node was not responding reliably to external traffic. The same port on `worker-prox` responded correctly.

### Fix

Configure all external Alloy agents to use the `worker-prox` IP as the Loki endpoint:

```
http://192.168.1.152:31010/loki/api/v1/push
```

For internal cluster traffic (e.g. Grafana datasource), use the in-cluster DNS name:

```
http://loki.loki.svc.cluster.local:3100
```

### Lesson

**A `NodePort` is accessible on all nodes, but in practice it may not respond reliably on every node for external traffic.** When a NodePort is not reachable on one node, try another node's IP before debugging further — the pod does not need to be on the node you connect to.

---

## Note: External VMs use Alloy, not Promtail

The VMs outside the cluster (Proxmox VMs running Ubuntu Server) ship logs using `alloy`, not `promtail`. When debugging log ingestion from these VMs, check the Alloy config and endpoint — not a Promtail installation that does not exist.

Alloy reads local log files correctly. The common failure point was the wrong Loki endpoint URL in the Alloy `loki.write` configuration.
