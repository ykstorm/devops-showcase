# devops-showcase

> A self-contained, GitOps-native, observability-rich Kubernetes
> platform on a local kind cluster — deploying
> `ghcr.io/ykstorm/buyerchat` through ArgoCD app-of-apps + Argo
> Rollouts + Sealed Secrets + ingress-nginx + cert-manager +
> Prometheus + Loki + Tempo + NetworkPolicies + Pod Security
> Standards. Reproducible from `make up` in under 10 minutes. $0
> infra cost.

**Status:** Sprint Week 1 in flight (Day 1 of 7 — scope locked).
Skeleton + documentation only at this commit. Cluster, charts, and
GitOps wiring land Day 2 through Day 7. See [the sprint
plan](docs/diagnostics/p3-week1/task_plan.md) for daily milestones.

---

## Why this exists

This repo is the platform-engineering counterpart to two
application-layer projects in the same portfolio:

- `buyerchat-p1` — a production Next.js + Prisma + Anthropic-streaming
  app. The image deployed here is built and published by that repo's
  GHA pipeline.
- `wellverse-p2` — frontend polish + dockerization on a small
  health-tech site.

Both ship working software. Neither *demonstrates* the platform on
which production software runs. This repo does. The deliverable is
a recruiter-friendly, reproducible, fully open-source platform — the
boring-but-credible footing under "I can build the app *and* the
infrastructure that hosts it."

---

## Quick links (Week 1)

- **[Locked scope](docs/P3-SCOPE.md)** — what ships, what defers, the
  10-item success-criteria checklist.
- **[Day-1 findings](docs/diagnostics/p3-week1/findings.md)** —
  toolchain inventory, GHCR probe result, 18 open questions resolved
  or escalated.
- **[7-day plan](docs/diagnostics/p3-week1/task_plan.md)** — daily
  goals, deliverables, acceptance criteria, commit messages,
  risk/fallback per day.
- **[Progress log](docs/diagnostics/p3-week1/progress.md)** — append-
  only daily reflection log.

---

## Quickstart (will land Day 2-7)

```bash
# Day 2:
bash scripts/bootstrap.sh           # kind cluster up + namespaces

# Day 3-5 (replaced Day 6 by ArgoCD):
bash scripts/install-foundation.sh  # ingress + cert-manager + sealed-secrets
bash scripts/install-observability.sh  # prometheus + loki + tempo

# Day 6:
bash scripts/install-argocd.sh      # ArgoCD + app-of-apps takes over

# Day 7:
make up      # one-command full bring-up (idempotent)
make down    # tear it all back down
```

For Day 1 specifically, there is nothing to run yet. Read the docs.

---

## Architecture (will land Day 7)

A mermaid request-flow + GitOps-flow + observability-flow diagram set
ships in `docs/architecture.md` on Day 7. Stub:

```
   browser
      │
      ▼ HTTPS (cert-manager self-signed CA)
ingress-nginx (LoadBalancer→hostport)
      │
      ▼
buyerchat Service (ClusterIP :3000)
      │
      ▼  (canary 25→50→75→100, Argo Rollouts)
buyerchat Pods (2 replicas, restricted PSS)
      ├──→ Prometheus  /api/metrics scrape
      ├──→ Promtail/Loki   stdout logs
      └──→ Tempo            OTLP traces (if image emits)
```

GitOps loop:

```
git push origin main
      │
      ▼
ArgoCD root Application (app-of-apps)
      │
      ▼
8 child Applications (sync waves: 0=foundation, 1=observability, 2=workload)
      │
      ▼
helm/argocd applies; Argo Rollouts kicks off canary on workload diff
```

---

## Anti-scope (what this repo deliberately does **not** do)

- No real cloud (AWS/GCP/Hetzner/etc.) — kind only.
- No real production secrets — every committed value is placeholder
  or sealed-secret-encrypted with the local cluster's controller
  key.
- No Istio/Linkerd, no Vault, no External Secrets Operator, no HPA/
  KEDA/VPA, no Velero, no SLO machinery, no cost dashboards.
- No frontend or backend changes to buyerchat — the image is
  consumed as an opaque artifact.

The full anti-scope list is in
[docs/P3-SCOPE.md §3](docs/P3-SCOPE.md#3-what-is-explicitly-out-of-scope-deferred-to-v10).

---

## Discipline

This sprint inherits the discipline framework from the sibling
`buyerchat-p1` repo's `docs/AGENT_DISCIPLINE.md`. Every day-end
commit's chat report carries:

```
[OK]/[PARTIAL]/[BLOCKED]/[NEEDS DECISION]
+ 3-line summary
+ commit SHA
+ files-changed count
+ discipline-checklist application line
```

The applicable discipline sections (and why) are mapped in
[docs/P3-SCOPE.md §7](docs/P3-SCOPE.md#7-discipline-references).

---

## Repo layout (post-Week-1)

```
devops-showcase/
├── kind/                  # Day 2 — cluster declaration
├── scripts/               # Day 2-6 — bring-up / teardown helpers
├── helm/buyerchat/        # Day 4 — workload chart
├── infra/                 # Day 3-6 — platform-component values
│   ├── ingress-nginx/
│   ├── cert-manager/
│   ├── sealed-secrets/
│   ├── kube-prometheus-stack/
│   ├── loki/
│   ├── tempo/
│   ├── argocd/
│   └── argo-rollouts/
├── argocd/                # Day 6 — app-of-apps + per-component apps
│   ├── app-of-apps/
│   └── apps/
├── policies/              # Day 7 — NetworkPolicy + PSS
│   ├── network/
│   └── pss/
├── ci/                    # Day 7 — workflow source
├── .github/workflows/     # Day 7 — symlinked from ci/
├── Makefile               # Day 7
└── docs/
    ├── P3-SCOPE.md
    ├── architecture.md
    ├── tradeoffs.md
    ├── runbooks/
    ├── retros/
    ├── screenshots/
    └── diagnostics/p3-week1/
```

The Day-of-write attribution for every file/directory is in
[findings.md §E](docs/diagnostics/p3-week1/findings.md#e-repo-skeleton-plan-write-order-by-day).

---

## License

TBD (will pick MIT or Apache-2.0 on Day 7 before the public push).

---

## Acknowledgements

- The discipline doc (`AGENT_DISCIPLINE.md`) and two-phase prompt
  pattern (`PROMPT_TEMPLATES.md`) carry over from the sibling
  `buyerchat-p1` repo. They were paid for in production incidents
  and are worth their weight.
- Every chart consumed here is upstream-maintained: kubernetes/
  ingress-nginx, jetstack/cert-manager, bitnami-labs/sealed-secrets,
  argoproj/argo-cd, argoproj/argo-rollouts,
  prometheus-community/kube-prometheus-stack, grafana/loki-stack,
  grafana/tempo. None are forked. All values files declare exactly
  what changed from upstream defaults and why.
