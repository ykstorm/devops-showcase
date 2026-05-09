# CodeCraft AI — DevOps Showcase

## What this project is

A self-contained, GitOps-native, observability-rich Kubernetes platform on a **local kind cluster** — deploys `ghcr.io/ykstorm/buyerchat` through:
- ArgoCD app-of-apps (GitOps control plane)
- Argo Rollouts (canary progressive delivery)
- ingress-nginx + cert-manager (TLS via self-signed CA)
- Sealed Secrets (encrypted secrets in git)
- Prometheus + Loki + Tempo (metrics + logs + traces)
- NetworkPolicy default-deny + Pod Security Standards "restricted"
- **$0 infra cost, reproducible from `make up` in under 10 minutes**

## Why it exists

Platform/SRE story to complement the application-layer projects (buyerchat, CodeCraft AI). Makes you credible as someone who can build both the app AND the infrastructure it runs on.

## Resume bullet

> Designed and shipped a portfolio Kubernetes platform demonstrating senior-level platform engineering: ArgoCD app-of-apps GitOps, Argo Rollouts canary deploys, Sealed Secrets, ingress-nginx + cert-manager TLS, Prometheus + Loki + Tempo three-pillar observability, network-policy default-deny + Pod Security Standards "restricted" enforcement — all on a local kind cluster reproducible from one `make up`.

---

## Current status

**Sprint Week 1 in flight — Day 3 complete (as of 2026-05-06)**

Progress log: `docs/diagnostics/p3-week1/progress.md`

| Day | Status | Theme |
|-----|--------|-------|
| 1 | ✅ [OK] | Investigation + scope lock + skeleton |
| 2 | ⚠️ [PARTIAL] | kind cluster + Calico + raw manifests + scripts |
| 3 | ✅ [OK] | ingress-nginx + cert-manager + sealed-secrets + Helm chart |
| 4 | 🔜 Next | Argo Rollouts + Prometheus + Loki + Tempo |
| 5 | 🔜 | Grafana dashboards + ArgoCD app-of-apps |
| 6 | 🔜 | CI/CD + NetworkPolicy refinements + PSS |
| 7 | 🔜 | Screenshots + retro + `make up` finalization |

### Day 2 known issues
- Criterion 7 (`scripts\down.ps1` clean teardown) deferred — cluster kept up for Day 3
- GHCR package is **public** (not private as Day-1 inferred) — `:latest` tag doesn't exist, use `:sha-8560cb3`
- Restricted PSS + Next.js standalone: `/tmp` and `/app/.next/cache` require emptyDir mounts (confirmed working)

### Day 3 confirmed
- 10/10 acceptance criteria verified live against kind cluster
- HTTPS smoke: `curl` returns `HTTP 503 {"status":"degraded","reason":"db_unreachable"}` via TLS
- SealedSecret round-trip confirmed (controller decrypts committed sealed secret to plaintext Secret in cluster)

---

## Repo layout

```
devops-showcase/
├── kind/                     # Cluster declaration + Calico CNI
│   ├── cluster.yaml          # Single-node kind cluster
│   └── calico/               # Tigera operator + Installation CR
├── scripts/
│   ├── up.ps1                # Bring up cluster + bootstrap
│   └── down.ps1              # Teardown (confirm-gated)
├── helm/buyerchat/           # Workload Helm chart
│   ├── Chart.yaml
│   ├── values.yaml           # Production defaults
│   ├── values.dev.yaml       # Kind-cluster overrides
│   └── templates/            # Deployment, Service, Ingress, NetworkPolicy, SealedSecret
├── infra/                    # Platform component values
│   ├── ingress-nginx/
│   ├── cert-manager/
│   ├── sealed-secrets/
│   ├── kube-prometheus-stack/
│   ├── loki/
│   ├── tempo/
│   ├── argocd/
│   └── argo-rollouts/
├── manifests/buyerchat/      # Raw YAML (legacy, migrating to helm/)
│   └── 00-namespace.yaml
├── docs/
│   ├── P3-SCOPE.md           # Sprint contract — READ FIRST
│   ├── architecture.md       # Request/GitOps/observability flow diagrams
│   ├── tradeoffs.md          # "Why X not Y" decisions
│   ├── runbooks/
│   │   ├── argocd-out-of-sync.md
│   │   ├── rollout-stuck.md
│   │   └── cert-manager-issues.md
│   └── diagnostics/p3-week1/
│       ├── findings.md       # Day 1 investigation
│       ├── task_plan.md      # 7-day plan
│       └── progress.md       # Append-only daily log
└── .github/workflows/         # CI (Day 7)
```

---

## Key files

| File | Purpose |
|------|---------|
| `docs/P3-SCOPE.md` | Sprint scope, success criteria, anti-touch list |
| `docs/diagnostics/p3-week1/task_plan.md` | Day-by-day plan with commit messages |
| `docs/diagnostics/p3-week1/progress.md` | Daily progress log |
| `helm/buyerchat/values.yaml` | Production buyerchat Helm values |
| `kind/cluster.yaml` | Kind cluster declaration |
| `scripts/up.ps1` | One-command cluster bring-up |

---

## Quickstart

```bash
# Day 7+ (after sprint completes):
make up      # Full bring-up — cluster + platform + workload
make down    # Clean teardown

# Manual (before Day 7 scripts land):
kind create cluster --config kind/cluster.yaml
kubectl apply -f kind/calico/
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx
# ... see P3-SCOPE.md §2.3 for full component table
```

---

## Buyerchat image

- **GHCR URL**: `ghcr.io/ykstorm/buyerchat:sha-8560cb3`
- **Note**: `:latest` does NOT exist (workflow doesn't publish it)
- **Auth**: Public package — no PAT needed
- **Health endpoint**: `/api/healthcheck` → `503 {"status":"degraded","reason":"db_unreachable"}` without real DB

---

## Anti-scope (don't touch)

- No cloud (AWS/GCP/Hetzner) — kind only
- No real secrets — every committed value is placeholder or SealedSecret-encrypted
- No Istio/Linkerd/Vault/ESO/HPA/KEDA/Velero
- No changes to buyerchat source — image consumed as opaque artifact
- No `kubectl --context` against non-kind clusters

---

## Discipline

Inherits discipline framework from `buyerchat/docs/AGENT_DISCIPLINE.md`.

Key rules that apply here:
- **§9**: `helm lint`, `kubeconform`, `kubeval` gates before commit
- **§10**: End-of-day commit carries: `[OK]/[PARTIAL]/[BLOCKED]` + SHA + files-changed + verify state
- **§13**: Progress log entry prepended each day
- **§14**: Verdict format on every report
- **§15**: ≥80% confidence → proceed + document. Cluster-destructive → escalate first
- **§16**: Day 7 retro (two paragraphs, SHA-cited)

---

## For sessions picking this up mid-sprint

1. Read `docs/P3-SCOPE.md` first (scope contract)
2. Read `docs/diagnostics/p3-week1/progress.md` (where we are)
3. Read `docs/diagnostics/p3-week1/task_plan.md` Day N row (what to do next)
4. Check `kind/cluster.yaml` context name: `kind-devops-showcase`
5. **Never edit buyerchat source** (`C:\Users\pc\Documents\buyerchat`) from this context
