# Calico CNI for kind

## Why Calico (not kindnet)

kindnet — the default CNI shipped with `kind` — supports basic pod-to-
pod networking but its NetworkPolicy enforcement is partial. Egress
rules in particular are not reliably honored. For a sprint that ships
a default-deny + explicit-allow NetworkPolicy demo as a top-line
deliverable, that's a hard blocker.

Calico:

- enforces both `Ingress` and `Egress` rules in full,
- is the de-facto industry default CNI on bare metal / VM Kubernetes,
- installs cleanly via the upstream `tigera-operator` manifest,
- adds ~30s to first-cluster bring-up and 2 controller pods of
  steady-state overhead.

The `kind/cluster.yaml` declares `disableDefaultCNI: true` so kindnet
never starts, leaving the cluster in a `NotReady` state until Calico
is applied.

## Pinned versions

- **Calico release:** `v3.28.2` (current LTS series at sprint start;
  bumped intentionally — see `docs/tradeoffs.md` Day 7).
- **tigera-operator manifest URL** (consumed by `scripts/up.ps1`):
  `https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml`

## Files

- `installation.yaml` — Calico `Installation` + `APIServer` custom
  resources. The operator reads these and reconciles the data-plane.
  IP pool aligned with `kind/cluster.yaml` `podSubnet: 192.168.0.0/16`.

## Bring-up order (handled by `scripts/up.ps1`)

1. `kubectl create -f <tigera-operator URL>` — deploys the operator
   into namespace `tigera-operator`.
2. `kubectl wait --for=condition=Available deployment/tigera-operator
   -n tigera-operator --timeout=180s` — operator must be ready before
   the Installation CR can be reconciled.
3. `kubectl apply -f kind/calico/installation.yaml` — operator picks
   up the CR, deploys `calico-node` (DaemonSet), `calico-kube-
   controllers`, and `calico-apiserver`.
4. `kubectl wait --for=condition=Ready node --all --timeout=300s` —
   nodes flip to Ready once Calico's data-plane is up.

## Verification

```powershell
kubectl get pods -A
# expect: tigera-operator/* Running, calico-system/* Running, no kindnet-*

kubectl get installation default -o jsonpath='{.status.state}'
# expect: Ready
```
