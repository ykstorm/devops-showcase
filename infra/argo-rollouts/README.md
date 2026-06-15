# argo-rollouts (P3 Day 6)

Installs the Argo Rollouts controller (namespace `argo-rollouts`). The
controller watches `Rollout` objects and drives the buyerchat canary
through its weight steps, pausing on each `analysis` step to evaluate the
`AnalysisTemplate` against Prometheus before advancing.

Unlike the older `infra/*` overlays, this directory is a self-contained
wrapper chart: `Chart.yaml` pins the upstream `argo/argo-rollouts` chart
(`2.41.0`) as a dependency, so the ArgoCD app-of-apps can point an
`Application` straight at it and `helm lint` runs in CI.

## Install / upgrade

```sh
helm dependency build infra/argo-rollouts
helm upgrade --install argo-rollouts infra/argo-rollouts \
  --namespace argo-rollouts --create-namespace \
  --wait --timeout 5m
```

## Verify

```sh
kubectl get pods -n argo-rollouts
# expect: argo-rollouts controller 1/1 Running

kubectl argo rollouts version
```
