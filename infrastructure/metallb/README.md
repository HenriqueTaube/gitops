# metallb

Bare-metal load balancer for the homelab cluster.

## Why

On bare-metal clusters there is no cloud provider to handle `LoadBalancer` type services. MetalLB fills that gap by assigning real IP addresses from a local address pool to services that request them.

The cluster uses Cilium as the CNI, which includes its own load balancer (CiliumLB). MetalLB was chosen anyway to keep the load balancer as a dedicated, separate component — easier to reason about and troubleshoot independently.

## Layout

- `base/`: Helm repository and release
- `overlays/homelab/`: address pool and L2 advertisement
