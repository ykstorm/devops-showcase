# CodeCraft AI — DevOps Showcase

## What this project is

A self-contained, GitOps-native, observability-rich Kubernetes platform on a **local kind cluster** — deploys `ghcr.io/ykstorm/buyerchat` through:

- **ArgoCD** app-of-apps (GitOps control plane — one root app manages 8 child apps)
- **Argo Rollouts** (canary progressive delivery: 25% → 50% → 75% → 100%)
- **ingress-nginx** + **cert-manager** (TLS via self-signed CA ClusterIssuer)
- **Sealed Secrets** (encrypted secrets committed to git; controller decrypts in-cluster)
- **Prometheus** + **Loki** + **Tempo** (metrics + logs + traces — the three-pillar observability stack)
- **Grafana** dashboards (RED metrics for buyerchat auto-imported via ConfigMap label trick)
- **NetworkPolicy** default-deny (ingress + egress) + **Pod Security Standards** `restricted` on workload namespaces
- **$0 infra cost, reproducible from `make up` in under 10 minutes**

The workload (`buyerchat`) boots in **degraded mode** (no real DB — `/api/healthcheck` returns `503 {"status":"degraded","reason":"db_unreachable"}`). This is intentional: the showcase is the Kubernetes platform, not a running homesty.ai clone. The RED dashboard panels surface the 503 rate, which is itself part of the demo.

---

## Architecture

### Request flow

```
browser
   │
   ▼ HTTPS (cert-manager self-signed CA, cert stored in Secret)
ingress-nginx controller (hostPort 80/443 on kind node)
   │
   ▼ TLS termination → proxy_pass buyerchat.app:3000
buyerchat Service (ClusterIP :3000)
   │
   ▼  (canary: 25% → 50% → 75% → 100%, Argo Rollouts controller)
buyerchat Pods (2 replicas, restricted PSS, emptyDir /tmp + /app/.next/cache)
   ├──→ Prometheus /api/metrics scrape (ServiceMonitor, 30s interval)
   ├──→ Promtail stdout logs → Loki
   └──→ OTLP traces → Tempo :4317 (if image emits traces natively)
```

### GitOps flow

```
git push origin main
        │
        ▼
ArgoCD root Application (app-of-apps, sync-policy: automated + prune + self-heal)
        │
        ▼
8 child Applications (sync waves: 0=foundation, 1=observability, 2=workload)
  ingress-nginx | cert-manager | sealed-secrets | argo-rollouts
  kube-prometheus-stack | loki | tempo
  buyerchat (Argo Rollouts Rollout CRD)
        │
        ▼
Argo Rollouts kicks off canary on image tag or values diff
```

### Platform components and their namespaces

| Layer | Component | Namespace | GitOps app name |
|-------|----------|-----------|-----------------|
| Ingress | `ingress-nginx` | `ingress-nginx` | `app-ingress-nginx` |
| TLS | `cert-manager` + `ClusterIssuer/selfsigned` | `cert-manager` | `app-cert-manager` |
| Secrets | `sealed-secrets` controller | `kube-system` | `app-sealed-secrets` |
| GitOps | `argo-cd` | `argocd` | `app-argocd` (root) |
| Progressive delivery | `argo-rollouts` controller | `argo-rollouts` | `app-argo-rollouts` |
| Metrics | `kube-prometheus-stack` (Prometheus + Grafana + exporters) | `monitoring` | `app-prometheus` |
| Logs | `loki` + `promtail` | `monitoring` | `app-loki` |
| Traces | `tempo` (monolithic mode) | `monitoring` | `app-tempo` |
| Workload | `buyerchat` (Helm chart) | `app` | `app-buyerchat` |

### Key architectural decisions (documented in `docs/tradeoffs.md`)

- **Self-signed CA vs ACME**: Local cluster can't reach Let's Encrypt's ACME endpoints. Self-signed `ClusterIssuer` works identically for TLS; swap is a one-line change.
- **Sealed Secrets vs ESO/Vault**: Enough for a showcase. Controller key is per-cluster and ephemeral — documented limit.
- **kube-prometheus-stack `serviceMonitorSelectorNilUsesHelmValues: false`**: Without this, the operator ignores ServiceMonitors from other releases (like our buyerchat chart). Critical wiring.
- **Grafana `grafana_dashboard: "1"` label trick**: Dashboards auto-import from any ConfigMap in any namespace — no Prometheus datasource re-pointing needed.
- **Tempo monolithic vs distributed**: Single binary, sufficient for showcase. Distributed mode adds ~3 more microservices and YAML.
- **kind vs k3d vs minikube vs cloud**: kind is the simplest, most portable, $0. k3d needs a container runtime inside Docker. minikube needs a VM driver. Cloud is out of scope.

---

## How to run locally

### Prerequisites

```bash
docker version          # Docker Desktop running
kind version           # v0.23+
helm version           # v3.15+
kubectl version        # v1.28+
git
```

### One-command bring-up

```bash
make up
```

This runs the full bootstrap sequence (see `Makefile` for details):

1. `kind create cluster --config kind/cluster.yaml` (single-node, Calico CNI, extraPortMappings 80/443)
2. Install Calico tigera-operator + Installation CR
3. Install platform Helm charts in dependency order: ingress-nginx → cert-manager → sealed-secrets → argo-rollouts → kube-prometheus-stack → loki → tempo → argocd
4. Install buyerchat Helm chart
5. Wait for all pods `Running`, ArgoCD apps `Synced` + `Healthy`
6. Print smoke-test commands

### One-command teardown

```bash
make down
```

Deletes the kind cluster. Clean — no leaked Docker networks or volumes.

### Manual smoke tests after `make up`

```bash
# Cluster up
kind get clusters                          # → devops-showcase
kubectl get pods -A                        # zero CrashLoopBackOff / Error

# ArgoCD GitOps health
kubectl get applications -n argocd         # root + 8 children, all Synced + Healthy
open https://argocd.local.devops-showcase.dev/  # admin password: see argocd/values.yaml

# Workload
curl https://buyerchat.local.devops-showcase.dev/api/healthcheck
# → HTTP 503 {"status":"degraded","reason":"db_unreachable"} via TLS

# Observability
open https://grafana.local.devops-showcase.dev/  # admin / prom-operator
# → Buyerchat RED dashboard renders (5xx panel shows non-zero — expected in degraded mode)
# → Loki Explore shows live pod logs
# → Tempo Explore shows traces (if buyerchat emits OTLP natively)

# Argo Rollouts
kubectl get rollout -n app buyerchat       # Healthy
kubectl argo rollouts get rollout buyerchat -n app --watch

# Prometheus targets
open https://prometheus.local.devops-showcase.dev/targets  # all UP

# NetworkPolicy enforcement
kubectl run test --image=alpine --rm -it -n app -- wget -qO- http://buyerchat:3000  # DENIED (default-deny)
kubectl run test --image=alpine --rm -it -n ingress-nginx -- wget -qO- http://buyerchat.app:3000  # ALLOWED
```

### Host file entries (required for browser access)

Add to `/etc/hosts` (or `C:\Windows\System32\drivers\etc\hosts` on Windows):

```
127.0.0.1 buyerchat.local.devops-showcase.dev
127.0.0.1 grafana.local.devops-showcase.dev
127.0.0.1 argocd.local.devops-showcase.dev
127.0.0.1 prometheus.local.devops-showcase.dev
```

---

## GitHub Actions workflows

### `.github/workflows/ci.yml`

Runs on every PR + push to `main`:

```yaml
jobs:
  lint:
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v4
        with: { version: 'v3.15+' }
      - run: helm lint helm/buyerchat
      - run: helm template helm/buyerchat | kubeconform -strict -summary -ignore-missing-schemas
      - run: kubeval infra/**/*.yaml argocd/**/*.yaml helm/**/*.yaml
      - run: yaml-lint *.yaml infra/**/*.yaml argocd/**/*.yaml helm/**/*.yaml

  # Optional ephemeral kind smoke test (gated on label 'run-kind-test: true')
  # Uncomment in ci.yml before Day-7 merge.
  # smoke-test:
  #   if: contains(github.event.pull_request.labels.*.name, 'run-kind-test')
  #   steps:
  #     - uses: actions/checkout@v4
  #     - run: kind create cluster --config kind/cluster.yaml
  #     - run: scripts/up.ps1  # or Makefile target
  #     - run: kubectl get pods -A --no-headers | grep -v Running
  #     - run: kubectl get applications -n argocd
```

**No deploy step from CI.** ArgoCD is the only mutator of cluster state. CI validates that Helm templates render, manifests conform to schemas, and YAML is valid.

---

## The `make up` command

`make up` is the single entry point for the entire showcase. Defined in `Makefile` at repo root.

```makefile
up:
	@echo "=== Creating kind cluster ==="
	kind create cluster --config kind/cluster.yaml
	kubectl apply -f kind/calico/
	@echo "=== Waiting for Calico operator ==="
	kubectl wait --for=condition=Available deploy/tigera-operator -n tigera-operator --timeout=120s
	kubectl apply -f kind/calico/installation.yaml
	@echo "=== Installing platform Helm charts ==="
	helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx -f infra/ingress-nginx/values.yaml
	helm install cert-manager jetstack/cert-manager -n cert-manager --set installCRDs=true
	kubectl apply -f infra/cert-manager/clusterissuer-selfsigned.yaml
	helm install sealed-secrets bitnami-labs/sealed-secrets -n kube-system -f infra/sealed-secrets/values.yaml
	helm install argo-rollouts argoproj/argo-rollouts -n argo-rollouts -f infra/argo-rollouts/values.yaml
	helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring -f infra/kube-prometheus-stack/values.yaml
	helm install loki grafana/loki-stack -n monitoring -f infra/loki/values.yaml
	helm install tempo grafana/tempo -n monitoring -f infra/tempo/values.yaml
	helm install argocd argoproj/argo-cd -n argocd -f infra/argocd/values.yaml
	@echo "=== Applying ArgoCD app-of-apps manifests ==="
	kubectl apply -f argocd/app-of-apps/
	@echo "=== Installing buyerchat workload ==="
	helm install buyerchat helm/buyerchat -n app -f helm/buyerchat/values.dev.yaml --wait
	@echo "=== Bootstrap complete ==="
	@echo "Run 'kubectl get pods -A' to verify, then 'make smoke' for full smoke test."
```

`make down` reverses everything:

```makefile
down:
	kind delete cluster --name devops-showcase
```

The Makefile is the only thing a recruiter or reviewer needs to run to see the full platform come up. No manual intervention after `make up`.

---

## Screenshots and media needed

Screenshots live in `docs/screenshots/` (commit as PNG or WebP). They are the proof that the demo actually works — a recruiter who clones the repo should be able to match what they see in the UI against these images.

### Required screenshots

1. **`argocd-app-of-apps.png`** — ArgoCD UI showing the root `app-of-apps` Application with all 8 children in a tree view, all `Synced` + `Healthy`. Label: "ArgoCD app-of-apps: all children healthy"

2. **`grafana-red-dashboard.png`** — Grafana "Buyerchat — RED" dashboard with 3 panels (Request Rate, Error Rate, p95 Latency). The error rate panel shows non-zero (expected — degraded mode). Label: "RED dashboard: 5xx rate visible in degraded mode"

3. **`grafana-loki-logs.png`** — Loki Explore panel showing live pod logs from `app/buyerchat-*` pods with the `{"status":"degraded"...}` JSON lines visible. Label: "Loki: buyerchat pod logs showing degraded-mode 503s"

4. **`grafana-tempo-trace.png`** — Tempo Explore trace view of a sample buyerchat request (traceparent header). Even if buyerchat doesn't emit native OTLP, capture a placeholder or the empty-state with a note. Label: "Tempo: distributed trace for buyerchat request"

5. **`argo-rollouts-canary.png`** — Argo Rollouts UI (via `kubectl argo rollouts dashboard` or in-cluster) showing a canary in progress through the 4-step plan (25→50→75→100). If no active rollout, show the healthy stable state with step indicator. Label: "Argo Rollouts: 4-step canary plan healthy"

6. **`prometheus-targets.png`** — Prometheus `/targets` page with `buyerchat` job `UP`. Label: "Prometheus: buyerchat target UP"

7. **`kubectl-get-pods.png`** — Terminal screenshot: `kubectl get pods -A` output showing all pods `Running`, spread across `app`, `ingress-nginx`, `cert-manager`, `monitoring`, `argocd`, `argo-rollouts` namespaces. Label: "All pods Running across all namespaces"

### How to capture

```bash
# Port forwards for browser screenshots
kubectl port-forward -n argocd svc/argocd-server 8080:443 &
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:3000 &
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &

# Argo Rollouts dashboard (separate terminal)
kubectl argo rollouts dashboard -n app &

# Use a screenshot tool (flameshot, Cmd+Shift+4, etc.)
# Save to docs/screenshots/
```

### Video walkthrough (stretch goal)

`docs/screenshots/demo.mp4` — 60-second walkthrough:
- `make up` running (accelerated 4x)
- browser visiting buyerchat, grafana, argocd
- git push triggering a canary promotion
- `kubectl argo rollouts get rollout buyerchat -n app --watch` showing step progression

---

## Project story (for portfolio purposes)

### The problem this solves

A portfolio that shows "I built a Next.js app" doesn't demonstrate that you can build the **platform** that app runs on. Recruiters at platform engineering / SRE / DevOps roles want to see infrastructure skills: GitOps, progressive delivery, observability, security policy enforcement, secrets management. This repo is the infrastructure story to go alongside the application layer stories (`buyerchat`, `wellverse`).

### What it demonstrates

**Senior-level platform engineering** across seven dimensions:

1. **GitOps**: ArgoCD app-of-apps pattern. One root Application manages 8 children with sync waves ordering foundation → observability → workload. Automated sync + prune + self-heal means the cluster always matches git.

2. **Progressive delivery**: Argo Rollouts with a 4-step canary (25→50→75→100). No metric analysis in v1.0 — the step plan is the progressive signal. Next step: add analysis template (Prometheus query gating the 25→50 transition).

3. **TLS automation**: cert-manager `ClusterIssuer` issues certs from a cluster-local CA. Self-signed CA works on kind without external network access; swap to `letsencrypt-prod` is a one-line change.

4. **Secrets without plaintext**: Sealed Secrets controller encrypts k8s Secret objects before committing to git. The controller key is per-cluster and ephemeral (documented limitation). Real production would use ESO + an external secrets manager.

5. **Three-pillar observability**: Prometheus scrapes buyerchat `/api/metrics` via ServiceMonitor. Grafana RED dashboard auto-imports from a ConfigMap with the `grafana_dashboard: "1"` label. Loki aggregates pod logs via Promtail. Tempo stores distributed traces (stretch if buyerchat emits OTLP natively).

6. **Network policy enforcement**: Calico CNI enforces `NetworkPolicy` rules that a vanilla kindnet CNI cannot. Default-deny ingress + egress in the app namespace with explicit allows for: ingress-nginx → buyerchat:3000, buyerchat → kube-dns:53, buyerchat → external HTTPS on an allowlist. Tested with `kubectl run test` from denied vs allowed namespaces.

7. **Defense in depth**: Pod Security Standards `restricted` on workload namespaces (app, argocd, monitoring); `baseline` on controller namespaces (ingress-nginx, cert-manager, sealed-secrets, argo-rollouts). Least-privilege security context on every pod (runAsNonRoot, drop ALL caps, readOnlyRootFilesystem, seccomp RuntimeDefault).

### Why it's credible

- **Reproducible in 10 minutes from `git clone`**: `make up` does it all. No manual intervention, no hidden state.
- **Every component is upstream-maintained**: No forked charts, no bespoke operators. When a recruiter asks "how does this work in production?" the answer is "exactly the same way, just point at real cloud credentials."
- **The 503 is a feature**: The degraded-mode healthcheck is intentional. It proves the dashboards work (they surface the error rate) and the observability pipeline is live.

### Resume bullet

> Designed and shipped a portfolio Kubernetes platform demonstrating senior-level platform engineering: ArgoCD app-of-apps GitOps, Argo Rollouts canary deploys, Sealed Secrets, ingress-nginx + cert-manager TLS, Prometheus + Loki + Tempo three-pillar observability, network-policy default-deny + Pod Security Standards "restricted" enforcement — all on a local kind cluster reproducible from one `make up`.

---

## Current status

**Sprint Week 1 — Day 3 complete (as of 2026-05-06)**

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

### Day 3 confirmed
- 10/10 acceptance criteria verified live against kind cluster
- HTTPS smoke: `curl` returns `HTTP 503 {"status":"degraded","reason":"db_unreachable"}` via TLS
- SealedSecret round-trip confirmed (controller decrypts committed sealed secret to plaintext Secret in cluster)
- Helm chart (`helm/buyerchat/`) owns Deployment + Service + Ingress + NetworkPolicies + SealedSecret

### Day 2 known issues
- Criterion 7 (`scripts\down.ps1` clean teardown) deferred — cluster kept up for Day 3
- GHCR package is **public** (not private as Day-1 inferred) — `:latest` tag doesn't exist, use `:sha-8560cb3`
- Restricted PSS + Next.js standalone: `/tmp` and `/app/.next/cache` require emptyDir mounts (confirmed working)

---

## Repo layout (as it exists after Day 3)

```
devops-showcase/
├── kind/                          # Cluster declaration + Calico CNI
│   ├── cluster.yaml               # Single-node kind cluster, extraPortMappings 80/443
│   └── calico/                   # Tigera operator + Installation CR
├── scripts/
│   ├── up.ps1                    # PowerShell bring-up (legacy, replaced by make up)
│   └── down.ps1                  # PowerShell teardown (legacy)
├── infra/                         # Platform Helm values
│   ├── ingress-nginx/values.yaml # hostPort enabled, Recreate strategy
│   ├── cert-manager/             # clusterissuer-selfsigned.yaml
│   ├── sealed-secrets/           # controller install
│   └── kube-prometheus-stack/values.yaml  # Grafana ingress, serviceMonitorSelectorNilUsesHelmValues: false
├── helm/buyerchat/               # Workload Helm chart
│   ├── Chart.yaml
│   ├── values.yaml               # Production defaults
│   ├── values.dev.yaml           # Kind-cluster overrides
│   └── templates/
│       ├── deployment.yaml       # restricted PSS, tcpSocket probes, emptyDir mounts
│       ├── service.yaml          # ClusterIP :3000
│       ├── ingress.yaml          # TLS via cert-manager selfsigned
│       ├── networkpolicy-deny.yaml
│       ├── networkpolicy-dns.yaml
│       ├── networkpolicy-ingress.yaml  # allows ingress-nginx + monitoring namespaces
│       ├── sealed-secret.yaml    # kubeseal-encrypted placeholder env vars
│       ├── servicemonitor.yaml    # Prometheus scraping via kps operator
│       └── _helpers.tpl
├── manifests/buyerchat/
│   └── 00-namespace.yaml         # buyerchat ns with PSS restricted labels
├── docs/
│   ├── P3-SCOPE.md              # Sprint contract — READ FIRST
│   ├── architecture.md          # Request/GitOps/observability flow diagrams
│   ├── tradeoffs.md             # "Why X not Y" decisions
│   ├── runbooks/
│   │   ├── argocd-out-of-sync.md
│   │   ├── rollout-stuck.md
│   │   └── cert-manager-issues.md
│   └── diagnostics/p3-week1/
│       ├── findings.md          # Day 1 investigation
│       ├── task_plan.md         # 7-day plan
│       └── progress.md          # Append-only daily log
└── .gitignore
```

**Pending (Days 4-7):**

- `infra/argo-rollouts/values.yaml` — Argo Rollouts controller install
- `infra/loki/values.yaml` — Loki + Promtail install
- `infra/tempo/values.yaml` — Tempo monolithic install
- `infra/argocd/values.yaml` + `argocd/app-of-apps/` + `argocd/apps/*.yaml` — ArgoCD app-of-apps
- `infra/kube-prometheus-stack/dashboards/buyerchat-red.json` — Grafana ConfigMap dashboard
- `.github/workflows/ci.yml` — lint gates
- `docs/screenshots/` — 7 mandatory screenshots
- `Makefile` — `make up` / `make down` / `make smoke`
- `docs/retros/p3-week1.md` — Day 7 retro

---

## Key files reference

| File | Purpose |
|------|---------|
| `docs/P3-SCOPE.md` | Sprint scope, success criteria, anti-touch list |
| `docs/diagnostics/p3-week1/task_plan.md` | Day-by-day plan with commit messages |
| `docs/diagnostics/p3-week1/progress.md` | Daily progress log |
| `kind/cluster.yaml` | Kind cluster declaration with extraPortMappings |
| `infra/kube-prometheus-stack/values.yaml` | Prometheus + Grafana install, critical `serviceMonitorSelectorNilUsesHelmValues: false` |
| `helm/buyerchat/values.yaml` | Production buyerchat Helm values |
| `helm/buyerchat/templates/servicemonitor.yaml` | Prometheus ServiceMonitor wiring |
| `infra/ingress-nginx/values.yaml` | hostPort + Recreate strategy for single-node kind |
| `infra/cert-manager/clusterissuer-selfsigned.yaml` | Self-signed CA issuer for TLS |
| `Makefile` | `make up` / `make down` (Day 7) |

---

## Buyerchat image details

- **GHCR URL**: `ghcr.io/ykstorm/buyerchat:sha-8560cb3`
- **Note**: `:latest` does NOT exist. The GHA workflow never publishes it.
- **Auth**: Public package — no PAT needed, no `imagePullSecret` needed
- **Health endpoint**: `/api/healthcheck` → `503 {"status":"degraded","reason":"db_unreachable"}` without a real Neon DB connection
- **Bootstrap behavior**: With stub env vars from the SealedSecret, buyerchat boots but the Prisma layer can't connect to a DB — hence the degraded 503. This is by design.

---

## Anti-scope (don't touch)

- No cloud (AWS/GCP/Hetzner) — kind only
- No real secrets — every committed value is placeholder or SealedSecret-encrypted
- No Istio/Linkerd/Vault/ESO/HPA/KEDA/Velero
- No changes to buyerchat source — image consumed as opaque artifact
- No `kubectl --context` against non-kind clusters
- No multi-cluster / ArgoCD ApplicationSet

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
5. **Never edit buyerchat source** from this context

---

## Quickstart (Day 7 target)

```bash
git clone https://github.com/ykstorm/devops-showcase.git
cd devops-showcase
make up      # Full bring-up: cluster + Calico + platform Helm charts + ArgoCD app-of-apps + buyerchat workload
# Add /etc/hosts entries (see above)
# Open browser at buyerchat.local.devops-showcase.dev, grafana.local.devops-showcase.dev, argocd.local.devops-showcase.dev

make down    # Clean teardown
```

For Day 1-6, use the scripts in `scripts/` or the Helm commands documented in each infra README.