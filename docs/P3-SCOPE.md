# P3 — DevOps Pipeline Showcase (locked scope, Week 1)

> **Locked 2026-05-03 (Day 1 of 7).** This file is the contract for the
> sprint. If a Day-N change deviates from this scope, update this doc
> _first_, in the same commit, with a note in
> `docs/diagnostics/p3-week1/progress.md`. Silent scope drift is the
> failure mode this sprint is designed against.

---

## 0. One-line elevator pitch

A self-contained, GitOps-native, observability-rich Kubernetes platform
running on a local kind cluster — deploys the existing
`ghcr.io/ykstorm/buyerchat` image through an industry-standard control
plane (ArgoCD app-of-apps + Argo Rollouts + Sealed Secrets +
ingress-nginx + cert-manager + Prometheus + Loki + Tempo + Network
Policies + Pod Security Standards), $0 infra cost, reproducible from
`make up` in under 10 minutes on any laptop with Docker + kubectl.

Resume bullet (target):

> _"Designed and shipped a portfolio Kubernetes platform that
> demonstrates senior-level platform engineering: ArgoCD app-of-apps
> GitOps, Argo Rollouts canary deploys, Sealed Secrets, ingress-nginx +
> cert-manager TLS, Prometheus + Loki + Tempo three-pillar
> observability, network-policy default-deny + Pod Security Standards
> 'restricted' enforcement — all running on a local kind cluster
> reproducible from one `make up`."_

---

## 1. Why this sprint exists

P1 (buyerchat audit-fields) and P2 (Wellverse polish) are application-
layer work. Recruiters scanning the portfolio see "Next.js engineer" and
stop. P3 is the platform/SRE story: the same engineer can stand up the
underlying infrastructure that runs those apps in production.

The constraint that makes this credible (and falsifiable) is that
**every artifact must be reproducible by a third party in under 10
minutes** with only Docker + a Unix-ish shell. No "trust me, it works on
my Hetzner box" — a recruiter who clones the repo and runs `make up`
either sees green dashboards or doesn't.

---

## 2. What ships in Week 1 (in scope)

### 2.1 Cluster

- **kind v0.23+** as the local Kubernetes control plane.
- Topology: **1 control-plane + 2 workers** (3-node, single Docker
  network). Lets us demonstrate node selectors and pod anti-affinity
  meaningfully without burning RAM.
- Kubernetes version pinned to **v1.30.x** (matches kind 0.23 default
  node image; well-supported by every chart we install).
- Cluster name: `devops-showcase`.

### 2.2 Workload

- **`ghcr.io/ykstorm/buyerchat:latest`** — the Next.js image already
  shipped from P1-R2 Day 6 GHCR push workflow. We deploy this as the
  example workload. We do **not** rebuild it, do **not** vendor its
  source, and do **not** ship secrets that would let it actually talk
  to its prod database.
- Helm chart at `helm/buyerchat/` — owned by this repo. Renders an
  Argo Rollouts `Rollout` CRD (canary, 4-step:
  25% → 50% → 75% → 100%, no metric analysis in v0.5), a `Service`,
  an `Ingress`, an optional `ServiceMonitor`, and a placeholder
  `SealedSecret` for `DATABASE_URL` etc.
- Healthcheck path: `/api/healthcheck` (already present in the image —
  see `buyerchat-p1/.github/workflows/docker.yml` history). On a kind
  cluster without a real Neon DB, this returns 503 (degraded). That is
  intentional and itself part of the demo: the dashboards must surface
  the 503 rate, the alerting rules must fire on it.

### 2.3 Platform components (installed via Helm, governed by ArgoCD)

| Layer | Component | Chart source | Namespace |
|---|---|---|---|
| Ingress | `ingress-nginx` | kubernetes/ingress-nginx | `ingress-nginx` |
| TLS | `cert-manager` + self-signed CA `ClusterIssuer` | jetstack/cert-manager | `cert-manager` |
| Secrets | `sealed-secrets` controller | bitnami-labs/sealed-secrets | `sealed-secrets` |
| GitOps | `argo-cd` (app-of-apps root + per-component Apps) | argoproj/argo-cd | `argocd` |
| Progressive delivery | `argo-rollouts` controller | argoproj/argo-rollouts | `argo-rollouts` |
| Metrics | `kube-prometheus-stack` (Prometheus, Alertmanager, Grafana, kube-state-metrics, node-exporter) | prometheus-community/kube-prometheus-stack | `monitoring` |
| Logs | `loki` + `promtail` | grafana/loki-stack | `monitoring` |
| Traces | `tempo` (monolithic mode) | grafana/tempo | `monitoring` |

### 2.4 Policy

- **NetworkPolicy default-deny** (ingress + egress) on `app` namespace,
  with explicit allows for: ingress-nginx → buyerchat:3000, buyerchat
  → kube-dns:53, buyerchat → external HTTPS (egress 443) on a
  selectable allowlist (Neon, OpenAI, Anthropic, Sentry — even though
  the demo doesn't reach them, the policy mirrors prod intent).
- **Pod Security Standards** at namespace level:
  - `app`, `argocd`, `monitoring` → `restricted`
  - `ingress-nginx`, `cert-manager`, `sealed-secrets`,
    `argo-rollouts` → `baseline` (these need slightly elevated perms
    for controller patterns; documented in `docs/tradeoffs.md`).

### 2.5 CI

- `.github/workflows/ci.yml` (named under `ci/` in repo, symlinked or
  generated into `.github/workflows/`) runs on every PR + push to main:
  - `helm lint helm/buyerchat`
  - `helm template helm/buyerchat | kubeconform -strict -summary
    -ignore-missing-schemas`
  - `kubeval` on every static manifest under `infra/` and `argocd/`
  - YAML lint on policy manifests
  - Optional: ephemeral `kind create cluster` smoke test (gated on a
    label, off by default — runners are slow)
- No deploy step from CI. ArgoCD is the only thing that mutates
  cluster state.

### 2.6 Documentation

- Architecture diagram in `README.md` (mermaid + a real screenshot)
- `docs/architecture.md` — request flow (browser → ingress → service
  → rollout → pod), GitOps flow (push to main → ArgoCD detect →
  app-of-apps reconcile → component apps sync → workload re-deploys),
  observability flow (pod stdout → promtail → loki; pod /metrics →
  prometheus; pod traces → otel-collector → tempo).
- `docs/tradeoffs.md` — every "why X not Y" decision with the
  reasoning. Self-signed CA vs ACME, ingress-nginx vs traefik,
  sealed-secrets vs ESO, app-of-apps vs ApplicationSet,
  monolithic-tempo vs distributed, kind vs k3d vs minikube vs cloud.
- `docs/runbooks/` — at minimum: "ArgoCD is OutOfSync, what now",
  "rollout stuck on step 2, what now", "pod CrashLoopBackOff, what
  now", "cert-manager won't issue a cert, what now". Three to five
  one-pagers max.
- `docs/diagnostics/p3-week1/` — sprint-internal docs (this directory).
- `docs/retros/p3-week1.md` — Day 7 retro per AGENT_DISCIPLINE §16.

### 2.7 Screenshots (Day 7 captures)

Mandatory for credibility:

1. ArgoCD UI: app-of-apps tree, all green
2. Grafana: buyerchat dashboard with RED metrics (rate, errors, p95)
3. Grafana: Loki panel showing live pod logs
4. Grafana: Tempo trace view of a sample request
5. Argo Rollouts dashboard: canary in progress
6. Prometheus targets page: every target healthy
7. `kubectl get pods -A` (terminal screenshot)

---

## 3. What is explicitly out of scope (deferred to v1.0+)

- **No real cloud.** No Hetzner, no AWS, no GKE/EKS/AKS.
- **No real secrets.** Every value in committed YAML is placeholder or
  SealedSecret-encrypted with the demo cluster's controller key. The
  sealing key itself never leaves the local `kind` node.
- **No multi-cluster.** ApplicationSet, Argo CD UI federation, fleet
  management — out of scope.
- **No service mesh.** Istio/Linkerd add ~30 min of bring-up and a lot
  of conceptual surface for limited demo value. Defer.
- **No Vault, no External Secrets Operator.** Sealed Secrets is enough
  for this scope.
- **No HPA / KEDA / VPA / Karpenter.** Static replicas (2) per workload.
- **No DR / backup story.** No Velero, no etcd snapshot automation.
- **No real chaos engineering.** A `kubectl delete pod` smoke test
  belongs in the demo script, not in a Litmus framework install.
- **No cost dashboards.** OpenCost would be excellent but doubles the
  monitoring footprint.
- **No SLO machinery.** PrometheusRule alerts are in scope; full
  Sloth-style SLO definitions are not.
- **No frontend changes to buyerchat.** This sprint never touches the
  buyerchat-p1 worktree.
- **No app rebuild.** We consume `:latest` from GHCR; if the image is
  broken, that's a P1-R3 problem, not this sprint's.

---

## 4. Success criteria (objective, falsifiable)

The sprint is "shippable" when **all** of the following pass on a fresh
laptop, in a clean shell, in under 10 minutes from `git clone`:

- [ ] `make up` completes without manual intervention
- [ ] `kubectl get pods -A` shows zero `CrashLoopBackOff` /
      `ImagePullBackOff` / `Error` after the bootstrap settles (60s
      grace window)
- [ ] `kubectl get applications -n argocd` shows root + every child
      app `Synced` + `Healthy`
- [ ] `https://argocd.local.devops-showcase.dev/` (via /etc/hosts +
      ingress) loads the ArgoCD UI over the self-signed CA cert
- [ ] `https://grafana.local.devops-showcase.dev/` loads Grafana, the
      buyerchat dashboard renders, RED panels populate within 60s
- [ ] `https://buyerchat.local.devops-showcase.dev/` loads (degraded
      503 healthcheck is acceptable; the page must serve)
- [ ] `kubectl rollout status rollout/buyerchat -n app` shows current
      generation healthy
- [ ] Triggering a Helm-values bump (image tag) in a branch and
      merging to main causes ArgoCD to detect + Argo Rollouts to
      promote + canary to complete within 10 minutes
- [ ] `kubectl run test --image=alpine --rm -it -n app -- wget
      http://buyerchat:3000` is **denied** by NetworkPolicy from a
      non-allowed namespace; allowed from ingress-nginx namespace
- [ ] `make down` returns the laptop to a clean state (no leaked kind
      networks, no dangling Docker volumes)

If any of these fail at end of Day 7, the sprint is `[PARTIAL]` not
`[OK]`, and the gap is documented in `docs/diagnostics/p3-week1/HANDOFF.md`.

---

## 5. Daily commit cadence (locked)

| Day | Theme | Branch | Commit prefix |
|---|---|---|---|
| 1 (today) | Investigation + scope lock + skeleton | `p3-day1-scope` | `docs(p3): day 1 — scope + investigation` |
| 2 | kind cluster + bootstrap scripts | `p3-day2-cluster` | `feat(p3): day 2 — kind cluster + bootstrap` |
| 3 | ingress-nginx + cert-manager + sealed-secrets | `p3-day3-foundation` | `feat(p3): day 3 — ingress + TLS + secrets` |
| 4 | helm/buyerchat chart + Argo Rollouts | `p3-day4-workload` | `feat(p3): day 4 — buyerchat helm + rollouts` |
| 5 | Prometheus + Loki + Tempo + dashboards | `p3-day5-observability` | `feat(p3): day 5 — observability stack` |
| 6 | ArgoCD + app-of-apps + per-app manifests | `p3-day6-gitops` | `feat(p3): day 6 — argocd app-of-apps` |
| 7 | Network policy + PSS + CI + retro + screenshots | `p3-day7-policy-ci-retro` | `feat(p3): day 7 — policies + CI + retro` |

Each day ends with a commit on the day's branch and a `git merge --no-ff`
(or PR, if the operator prefers GitHub UI) into `main`. `main` is the
GitOps source-of-truth for ArgoCD.

---

## 6. Anti-touch list

- `C:\Users\pc\Documents\buyerchat-p1\` — never edit. Never import
  source. Never read its `.env`. Reading docs (per discipline section
  references) is allowed.
- `C:\Users\pc\Documents\d6-portfolio\` (or wherever the portfolio site
  lives) — out of scope for week 1; cross-link added in week 2.
- Any file containing real `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
  `DATABASE_URL` for Neon, Sentry DSN — never committed, never inlined,
  never used as test fixture even in `.env.example`.
- `--no-verify` on commit — no.
- `kubectl --context` against any cluster other than `kind-devops-showcase`.
- Any cloud provisioning (`terraform apply` against AWS/GCP/Hetzner,
  `gcloud`, `az`, `aws`, `hcloud` mutations).

---

## 7. Discipline references

This sprint inherits the discipline framework from
`buyerchat-p1/docs/AGENT_DISCIPLINE.md`. Section applicability:

- **§9 (lint/build/test gates):** `helm lint`, `kubeconform`,
  `kubeval`, plus `make verify` aggregator.
- **§10 (report-back format):** every day-end commit's chat report
  carries SHA + files-changed counts + verify state.
- **§11 (sub-agent rules):** if any day spawns parallel research
  agents, the day's prompt restates this scope doc and the day's
  `task_plan.md` row.
- **§13 (handoff):** `docs/diagnostics/p3-week1/progress.md` gets a
  prepended Day-N entry every day; `HANDOFF.md` (created Day 7) is the
  sprint-close artifact.
- **§14 (verdict format):** every chat report opens with
  `[OK]/[PARTIAL]/[BLOCKED]/[NEEDS DECISION]` + 3-line summary.
- **§15 (autonomous decisions):** ≥80% confidence proceed + document
  in commit body. Cluster-destructive ops (`kind delete cluster`,
  `helm uninstall` on populated namespace, `kubectl delete ns
  --cascade`) escalate.
- **§16 (retro):** Day 7 produces `docs/retros/p3-week1.md`.

§§1-8 are application-layer rules that don't bind here, with one
exception: **§7 (schema write provenance) maps to "no real secrets in
manifests"** — Sealed Secrets exists in this sprint precisely because
the same mistrust pattern (don't write trust-bearing values without
provenance) applies to cluster secret material.

---

## 8. Definition of done (sprint-level)

```
[OK] when:
  - All 10 success criteria in §4 pass
  - All 7 daily commits land on main with §10-format chat reports
  - docs/retros/p3-week1.md exists, two paragraphs, SHA-cited
  - 7 screenshots present under docs/screenshots/
  - HANDOFF.md exists with verify-state baseline table

[PARTIAL] when:
  - 7-9 of 10 criteria pass; gap documented
  - At most 1 day's commit deferred and tracked in HANDOFF "deferred"

[BLOCKED] when:
  - GHCR image is private and operator hasn't supplied a PAT for
    imagePullSecret (Day 4 hard block)
  - Docker Desktop won't start on the operator's machine (Day 2 hard
    block)
  - Any other hard external dependency the operator must resolve
```
