# GitOps and progressive delivery

This cluster is reconciled by ArgoCD from git, and the buyerchat workload
ships through an Argo Rollouts canary. This page describes both.

## App-of-apps

ArgoCD runs in the `argocd` namespace (installed from `infra/argocd`, a
wrapper chart that pins the upstream `argo/argo-cd` chart). The entry
point is one root `Application`:

```sh
kubectl apply -f argocd/root-app.yaml
```

`root` points at `argocd/apps/` in this repo. Every file there is itself
an `Application`, one per platform component, so reconciling `root` pulls
in the whole tree. The six children are:

| Application | Source | Namespace |
|---|---|---|
| `ingress-nginx` | upstream chart + `infra/ingress-nginx/values.yaml` | `ingress-nginx` |
| `cert-manager` | upstream chart (`installCRDs=true`) | `cert-manager` |
| `sealed-secrets` | upstream chart | `kube-system` |
| `kube-prometheus-stack` | upstream chart + `infra/kube-prometheus-stack/values.yaml` | `monitoring` |
| `argo-rollouts` | `infra/argo-rollouts` wrapper chart | `argo-rollouts` |
| `buyerchat` | `helm/buyerchat` with `values.dev.yaml` | `app` |

Each child and the root run `syncPolicy.automated` with `prune: true` and
`selfHeal: true`: git is the source of truth. A resource deleted from git
is pruned from the cluster; an out-of-band cluster edit is reverted on the
next sync.

The values-only overlays (ingress-nginx, kube-prometheus-stack) use an
ArgoCD multi-source `Application`: one source is the pinned upstream chart,
the second is this repo, referenced as `$values` so the chart reads the
in-repo values file. The two wrapper charts (argo-rollouts, argocd) are
self-contained — their `Chart.yaml` pins the upstream chart as a
dependency, so a single in-repo path renders them.

## Bootstrap vs. takeover

`make up` (and `scripts/up.ps1`) install the platform charts directly with
`helm upgrade --install` to get a clean machine to a working state, then
apply `argocd/root-app.yaml`. From that point ArgoCD owns the components
and reconciles them from `main`. The direct helm installs are the
bootstrap; the root app is the handoff.

## Canary

With `rollout.enabled: true` (set in `helm/buyerchat/values.dev.yaml`) the
buyerchat chart renders an Argo `Rollout` instead of a `Deployment`. The
pod template is identical — same security context, tcpSocket probes,
volumes, and NetworkPolicies carry over unchanged. Only the rollout
strategy differs:

```
setWeight 25 → pause 30s → analysis → setWeight 50 → pause 30s
            → setWeight 75 → pause 30s → setWeight 100
```

Watch a rollout advance:

```sh
make rollout-status
# kubectl argo rollouts get rollout buyerchat -n app --watch
```

### The analysis gate

The `analysis` step (after the 25% weight) runs the
`buyerchat-success-rate` `AnalysisTemplate`. It queries Prometheus (the
`kps` release, at `http://kps-kube-prometheus-stack-prometheus.monitoring:9090`)
three times at 30s intervals. If the success condition fails more than
once, the Rollout aborts and reverts to the previous revision.

The query today is a conservative liveness check — the fraction of
buyerchat targets Prometheus reports as scrapeable. The buyerchat image
runs degraded (no DB) and its exported metric names are not confirmable
from this repo, so the template does not claim a request-success-rate gate
it cannot compute. A `TODO` in `helm/buyerchat/templates/analysis-template.yaml`
marks the one query to replace once the image exports request counters on
`/api/metrics`.

## Maintenance note

The buyerchat pod template lives in both `deployment.yaml` and
`rollout.yaml` (one renders, the other is suppressed by
`rollout.enabled`). A change to the pod spec must be made in both files.
Extracting the shared template into a `_helpers.tpl` named template would
remove the duplication — a worthwhile follow-up.
