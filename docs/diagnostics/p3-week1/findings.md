# P3 Week 1 — Day 1 Findings (read-only investigation)

**Captured:** 2026-05-03
**Sprint phase:** Phase 1 (investigation only, no installs, no
mutations).
**Discipline sections applied:** §9, §10, §13, §14, §15 (per
`buyerchat-p1/docs/AGENT_DISCIPLINE.md`). §§1–8, §11, §12, §16 are
either application-layer (n/a yet) or end-of-sprint (§16).

> All file references in this document are absolute paths to the
> checked-out repo state at time of capture, with line numbers where
> the source has lines. Cross-repo references (to `buyerchat-p1`) cite
> their absolute path.

---

## A. Current state of `devops-showcase/`

**Working directory:** `C:\Users\pc\Documents\devops-showcase`

**State at investigation start (pre any Day 1 writes):**

- `git status` → `fatal: not a git repository` — directory is not yet
  initialized as a git repo.
- `ls -la` → only `.` and `..` entries (zero existing files).
- The directory is **truly empty**. No partial scaffolding from prior
  sessions, no carryover decisions to honor.

**State at end of Day 1 (after writes):**

```
devops-showcase/
├── .gitignore
├── README.md
└── docs/
    ├── P3-SCOPE.md                                (locked scope contract)
    └── diagnostics/
        └── p3-week1/
            ├── findings.md                        (this file)
            ├── task_plan.md                       (7-day plan)
            └── progress.md                        (Day 1 entry only)
```

No source code. No Helm charts. No infra manifests. No CI workflows.
Day 1 ships documentation and a minimal repo skeleton — nothing
executable, nothing the cluster could consume.

---

## B. Local toolchain inventory

Verified by direct command execution at investigation time:

| Tool      | Required for       | Installed? | Version observed                                 | Day-2 action |
|-----------|--------------------|-----------|--------------------------------------------------|--------------|
| `docker`  | Container runtime, kind backing | YES (engine NOT running) | `Docker version 24.0.7, build afdd53b`           | Operator must start Docker Desktop before Day 2 begins. |
| `kubectl` | All cluster ops    | YES        | `Client v1.28.2, Kustomize v5.0.4-0.20230601...` | Acceptable. Server will be 1.30 (kind default); 1.28 client → 1.30 server is within the supported skew of one minor (drift in either direction up to N±1 is supported by kubectl). |
| `helm`    | Chart install ops  | **NO**     | `bash: helm: command not found`                  | **Install Day 2.** Pin to v3.15+. Recommended path: `winget install Helm.Helm` or download release zip + add to PATH. |
| `kind`    | Local Kubernetes   | **NO**     | `bash: kind: command not found`                  | **Install Day 2.** Pin to v0.23+. Recommended path: `go install sigs.k8s.io/kind@v0.23.0` or download Windows release binary. |
| `git`     | Version control    | YES        | (implicit; `git status` errored cleanly with the not-a-repo message, which means the binary is on PATH) | OK. |
| `curl`    | Registry probes    | YES        | (implicit; used in this investigation)           | OK. |
| `make`    | `make up` UX target | UNKNOWN    | Not yet probed                                  | Verify Day 2; if absent, fall back to `scripts/up.sh`. Windows-native operators may prefer the script anyway. |
| `kubeconform` | CI lint        | UNKNOWN    | Not yet probed                                  | CI runner installs (Day 7). Local install optional. |
| `kubeseal`    | SealedSecret encryption | UNKNOWN | Not yet probed                              | Day 3 install — same machine, paired with sealed-secrets controller. |
| `terraform`   | (No longer needed — see §C decision Q-T) | n/a | n/a                                       | Dropped from elevated scope. Not required. |

### B.1 Docker engine state

`docker info` failed with:

> `error during connect: this error may indicate that the docker
> daemon is not running: open //./pipe/docker_engine: The system cannot
> find the file specified.`

This is not a missing-binary problem; the Docker Desktop UI is not
running. Day 2 begins with: operator launches Docker Desktop → wait
for the whale icon → re-run `docker info` → continue.

### B.2 GHCR pull verification (objective C of pre-flight)

The pre-flight asked us to confirm `docker pull
ghcr.io/ykstorm/buyerchat:latest` succeeds. We **could not** because
the Docker daemon is not running. As a partial substitute we probed
the GHCR registry HTTP API directly:

| Probe                                                                 | Result                                              |
|-----------------------------------------------------------------------|-----------------------------------------------------|
| `GET /v2/ykstorm/buyerchat/manifests/latest` (no auth)                | HTTP 401 (expected — GHCR requires bearer for everything) |
| `GET /token?scope=repository:ykstorm/buyerchat:pull&service=ghcr.io`  | HTTP 200, anonymous bearer issued                   |
| `GET /v2/ykstorm/buyerchat/manifests/latest` (anonymous bearer)       | **HTTP 404, zero-byte body**                        |

A 404 with the anonymous bearer is consistent with **either**:

1. The package exists but is **private**, and an anonymous-pull token
   is not authorized to read its manifest.
2. The package does not exist, or the `:latest` tag does not exist on
   it.

Cross-reference: `buyerchat-p1/.github/workflows/docker.yml` (read by
this investigation via `buyerchat-p1/docs/diagnostics/p1-week1/HANDOFF.md`
lines 96-101) confirms the workflow pushes `latest`, `sha-<short>`, and
`<semver>` tags on every push to `main` and on tag events. P1-R2 Day 6
shipped on commit `9a02c24` and Day 7 closed on `ec1e10c` (HANDOFF.md
lines 51 and 423). So a `:latest` tag almost certainly exists; the 404
under anonymous credentials therefore points at **case 1: the package
is private**.

**Day 2-3 implication.** If the package is private, the kind cluster's
`buyerchat` Deployment/Rollout will need an `imagePullSecret`
referencing a Docker config JSON containing a GHCR PAT (read:packages
scope). The `kubectl create secret docker-registry ghcr-pull ...`
recipe is well-known. The PAT itself does **not** go in the repo;
only the Sealed Secret encrypted form does. Day 3 has a sealed-secrets
controller install for exactly this.

**[NEEDS DECISION → resolved at 90% confidence]:** Treat the package
as private. Day 4 wires `imagePullSecrets: [name: ghcr-pull]` into the
buyerchat Helm chart `values.yaml`, with the actual secret created
from a Day-3 Sealed Secret. Operator must supply a GHCR PAT
(read:packages, no expiry shorter than 90d) at Day 3 kickoff. If it
turns out the package is public, the imagePullSecrets reference is
harmless and we drop the Sealed Secret in a follow-up.

---

## C. Open questions, resolutions, and decision log

The pre-flight asked: "Identify open questions that need a decision
before Day 2 (resolve at ≥80% confidence inline; escalate the rest)."

Each entry below is tagged **[RESOLVED]** (≥80% confidence, proceeding)
or **[NEEDS DECISION]** (operator input required before Day 2 can
start).

### Q-1. Cluster topology — 1 control + 2 workers, or 1+1?

**[RESOLVED, 90%]** — 1 control + 2 workers.

- Pro: lets us demonstrate `topologySpreadConstraints` and pod
  anti-affinity meaningfully (need ≥2 worker nodes for the assertion
  to even compile).
- Pro: kube-prometheus-stack default scrape config picks up multiple
  kubelets — richer Grafana node-exporter dashboards.
- Con: ~+1 GB RAM headroom required vs single-worker. Acceptable on a
  modern laptop with 16+ GB.
- The original v0.5 prompt (`buyerchat-p1/docs/diagnostics/p3-prompt.md:87`)
  also chose 3-node for the same reasons.

### Q-2. Container runtime under kind?

**[RESOLVED, 100%]** — containerd (kind default; not a real choice).

### Q-3. Ingress class — ingress-nginx or traefik?

**[RESOLVED, 95%]** — ingress-nginx.

- ingress-nginx is the most-deployed K8s ingress in the wild
  (industry-standard, more familiar to recruiters scanning the repo).
- Cleaner cert-manager integration patterns than traefik.
- Traefik's CRD model is interesting but adds conceptual surface that
  isn't differentiating in a portfolio context.

### Q-4. TLS strategy — Let's Encrypt or self-signed CA?

**[RESOLVED, 90%]** — self-signed CA via cert-manager `ClusterIssuer`
(the `CA` issuer kind, not `Acme`).

- Local kind cluster has no public DNS → ACME HTTP-01 fails.
- DNS-01 needs a real domain + DNS provider plugin → out of $0 scope.
- Self-signed CA gives the **same** cert-manager API surface
  (`Certificate`, `Issuer`, `ClusterIssuer`) without external
  dependencies. The demo flow is identical: a `Certificate` resource
  is created, cert-manager issues a cert from the CA, the secret is
  mounted by ingress.
- `docs/tradeoffs.md` will document the one-line ClusterIssuer change
  required to swap to ACME in real prod.

### Q-5. GitOps repo layout — monorepo or split?

**[RESOLVED, 95%]** — monorepo.

- This repo holds `helm/`, `argocd/apps/`, `infra/`, `policies/`,
  `ci/` together. ArgoCD Applications point at directories within the
  same repo.
- Standard and well-recognized pattern for portfolio scope. Splitting
  into `devops-showcase-charts` + `devops-showcase-argocd` adds zero
  signal and doubles repo overhead.

### Q-6. App-of-apps vs ApplicationSet?

**[RESOLVED, 95%]** — literal app-of-apps.

- ApplicationSet shines on multi-cluster or generator-driven
  templating; we have neither.
- App-of-apps is a single root `Application` pointing at
  `argocd/apps/`, where every YAML is itself an `Application` for one
  component. Easier to read, easier to demo.
- Both approaches are CNCF-blessed; choosing the simpler one is the
  right portfolio call.

### Q-7. Sealed Secrets vs External Secrets Operator vs Vault?

**[RESOLVED, 100%]** — Sealed Secrets.

- User explicitly listed `sealed-secrets` in the elevated scope.
- For local-cluster + $0-budget + portfolio scope, Sealed Secrets is
  the right fit: no external KMS dependency, the controller's private
  key lives on the cluster, encryption is per-cluster.
- ESO needs a backend (AWS Secrets Manager / GCP Secret Manager / Vault)
  → would push the demo onto a paid cloud or onto a self-hosted Vault
  install (another half-day of bring-up).

### Q-8. Argo Rollouts strategy — canary or blue-green?

**[RESOLVED, 85%]** — canary, 4-step (25 → 50 → 75 → 100), no
analysis template (yet).

- Canary is the strategy operators most often want to demonstrate
  ("show me a real progressive rollout").
- 4-step gives enough cadence to capture mid-rollout screenshots.
- Analysis template (auto-promote/-rollback based on Prometheus
  metrics) is a stretch goal for Day 6 — wired in as a separate
  AnalysisTemplate ConfigMap that's referenced by the Rollout but
  doesn't gate promotion if Prometheus disagrees. Stretch because
  configuring an Argo Rollouts Prometheus AnalysisTemplate against a
  cluster-internal Prometheus URL is fiddly enough to eat time
  budget.

### Q-9. Pod Security Standards level?

**[RESOLVED, 85%]** — `restricted` on `app`, `argocd`, `monitoring`;
`baseline` on `ingress-nginx`, `cert-manager`, `sealed-secrets`,
`argo-rollouts`.

- `restricted` is the strongest PSS profile. The buyerchat workload
  doesn't need root, host network, or privileged ops — it should run
  comfortably under `restricted`.
- Controllers (ingress controller, cert-manager webhook,
  sealed-secrets controller, argo-rollouts controller) have known
  patterns that occasionally trip `restricted` (e.g.,
  `runAsNonRoot:true` enforcement on init containers, seccomp profile
  defaults). `baseline` is the conservative choice; we can tighten in
  v1.0 with profile-specific exemptions.
- `docs/tradeoffs.md` documents the per-namespace assignment.

### Q-10. NetworkPolicy default?

**[RESOLVED, 95%]** — default-deny (ingress + egress) on the `app`
namespace, with explicit allow rules.

- Industry-recommended pattern: deny by default, allow by exception.
- The allow set: ingress-nginx → buyerchat:3000; buyerchat → kube-dns
  (UDP 53, TCP 53); buyerchat → external HTTPS (egress 443) with a
  CIDR allowlist that mirrors prod intent (Neon, OpenAI, Anthropic,
  Sentry — even though the demo doesn't reach them, the policy
  declares the boundary).
- Other namespaces (`monitoring`, `argocd`, `ingress-nginx`,
  `cert-manager`, etc.) start with no NetworkPolicy at all (i.e.,
  default-allow). Tightening them is a v1.0 stretch.

### Q-11. Buyerchat image source for the Helm chart `values.yaml`?

**[RESOLVED, 100%]** — `ghcr.io/ykstorm/buyerchat:latest`.

- This is the artifact already published by the P1-R2 Day 6 GHA
  pipeline. We pull it; we never rebuild.

### Q-12. Buyerchat secrets — what does the pod actually need to start?

**[NEEDS DECISION → resolved at 80% confidence, flagged for Day 4
operator review]** — Run in **degraded mode**: ship placeholder
SealedSecrets with non-functional values (`DATABASE_URL=postgres://demo:demo@example.invalid/demo`,
`OPENAI_API_KEY=sk-demo-not-real`, etc.). The pod boots, the Next.js
server starts, the `/api/healthcheck` returns 503 because the DB
ping fails — and that 503 rate is itself the visible signal on the
Grafana dashboard. The dashboards demonstrate they correctly catch a
broken downstream.

- Pro: $0 cost (no real Neon project), no real-secret risk in the
  repo, the demo *demonstrates* the observability stack catching a
  problem.
- Con: a recruiter scrolling the dashboards sees a non-zero error
  rate and may misread it as a bug rather than an intentional demo
  signal. **Mitigation:** the README's quickstart calls this out
  explicitly, and the dashboard has a side panel labeled "expected:
  /api/healthcheck → 503 in demo mode (no DB wired)".
- The alternative — ship a Postgres pod inside the cluster, point
  buyerchat at it, run prisma migrations on bring-up — is plausible
  but adds ~half a day of bring-up reliability work (init containers,
  migration job, secret rotation between Postgres pod and buyerchat
  pod, persistent-volume cleanup on `make down`). Out of week-1 scope.

**Operator hook:** if the operator prefers the "real local DB" route,
flag at Day 4 kickoff and we re-scope. Default proceeds with degraded
mode.

### Q-13. Loki vs full LGTM stack?

**[RESOLVED, 95%]** — `grafana/loki-stack` chart.

- Bundles Loki + Promtail + Grafana datasource auto-config. One
  install, one namespace.
- Same chart used in the saved v0.5 prompt
  (`buyerchat-p1/docs/diagnostics/p3-prompt.md:99`).

### Q-14. Tempo deployment mode — monolithic or distributed?

**[RESOLVED, 100%]** — monolithic on a local kind cluster. Distributed
mode (separate distributor / ingester / querier) is for prod scale
and adds 4-5 pods of overhead.

### Q-15. CI scope?

**[RESOLVED, 90%]** — lint-only on every PR/push:

- `helm lint helm/buyerchat`
- `helm template helm/buyerchat | kubeconform -strict -summary
  -ignore-missing-schemas`
- `kubeval` on every static manifest under `infra/` and `argocd/`
- YAML lint on policies
- Optional: `kind` smoke test gated behind a `run-kind-smoke` PR
  label (off by default)

No deploy from CI. ArgoCD is the only thing that mutates cluster
state. The CI's job is to **prevent** broken manifests reaching the
default branch where ArgoCD would happily reconcile them.

### Q-16. Branch strategy?

**[RESOLVED, 90%]** — daily branches, fast-forward (or `--no-ff`)
merge to `main` at end of day. Single-developer portfolio repo, no
PRs required (operator can opt into PRs via GitHub UI for the
recruiter-visible review trail; the merge protocol is the same).

### Q-17. Should Day 1 do `git init` + initial commit?

**[RESOLVED, 90%]** — Yes.

- The user's "no installs / no docker run / no kind / no helm"
  list is about runtime/cluster state. `git init` is local-only,
  trivially reversible (`rm -rf .git`).
- The deliverables list explicitly says ".gitignore + README.md
  skeleton" — those only mean something inside a git repo.
- AGENT_DISCIPLINE §10 wants a SHA in the report-back. We need a
  commit to produce one.
- We **do not** add a remote, **do not** push. Operator owns the
  GitHub repo creation and `git remote add origin` step.

### Q-T. Drop Terraform from the v0.5 saved prompt?

**[RESOLVED, 90%]** — Yes, drop.

- The saved v0.5 prompt
  (`buyerchat-p1/docs/diagnostics/p3-prompt.md:84-89`) used Terraform
  to wrap `kind create cluster`. The elevated scope replaces that
  with `kind/cluster.yaml` + `scripts/bootstrap.sh`.
- Terraform shelling out to `kind` via `null_resource` + `local-exec`
  is Terraform-as-shell-script — adds the `.terraform/` and
  `.tfstate` overhead without buying real declarative semantics on a
  resource the kind CLI already declares perfectly well via its YAML
  config.
- Honest tradeoff. Documented in `docs/tradeoffs.md` Day 7.
- This is a deviation from the saved Day-1-of-6 prompt and **must**
  be acknowledged in the locked scope (P3-SCOPE.md §2.1) so the
  scope-drift trail is clear.

### Q-18. Should Day 1 bootstrap a `.github/workflows/` placeholder?

**[RESOLVED, 95%]** — No.

- Day 7 owns CI. Day 1 stops at documentation + skeleton dirs that
  exist mainly via the `docs/` tree. Empty `infra/` /
  `helm/buyerchat/` / `argocd/` / `policies/` / `ci/` / `scripts/`
  directories are written by their owning day, not pre-stubbed. This
  keeps `git log` honest about which day actually shipped each
  surface.

---

## D. Day-2 preconditions (must be true before Day 2 begins)

These are operator actions, not auto-installable from this sprint:

1. **Start Docker Desktop.** Verify with `docker info` returning a
   non-error response.
2. **Install Helm v3.15+.** Recommended: `winget install Helm.Helm`.
3. **Install kind v0.23+.** Recommended: download Windows release
   binary into a directory on `$PATH`.
4. **Confirm GHCR pull works once Docker is up:**
   `docker pull ghcr.io/ykstorm/buyerchat:latest`. If 401/403,
   provide a GHCR PAT for Day 3 sealed-secret encoding.
5. (Optional) **Install `make` for Windows.** If absent, Day 7's
   `make up` ships a `scripts/up.sh` fallback.
6. (Optional) **Verify hosts file write permission.** Day 6 wires
   `*.local.devops-showcase.dev` entries to 127.0.0.1 via
   `C:\Windows\System32\drivers\etc\hosts`. Operator may prefer
   Acrylic DNS or `dnsmasq`-on-WSL — either works; `hosts` is the
   default.

---

## E. Repo skeleton plan (write order, by day)

```
devops-showcase/
├── .gitignore                                       (Day 1) ← TODAY
├── README.md                                        (Day 1) ← TODAY
├── Makefile                                          (Day 7)
├── kind/
│   └── cluster.yaml                                 (Day 2)
├── scripts/
│   ├── bootstrap.sh                                 (Day 2)
│   ├── seal-secret.sh                               (Day 3)
│   └── port-forward.sh                              (Day 6)
├── helm/
│   └── buyerchat/
│       ├── Chart.yaml                               (Day 4)
│       ├── values.yaml                              (Day 4)
│       ├── values.demo.yaml                         (Day 4)
│       └── templates/
│           ├── rollout.yaml                         (Day 4)
│           ├── service.yaml                         (Day 4)
│           ├── ingress.yaml                         (Day 4)
│           ├── servicemonitor.yaml                  (Day 5)
│           ├── sealedsecret.yaml                    (Day 4 placeholder, Day 3-encrypted)
│           ├── networkpolicy.yaml                   (Day 7)
│           └── _helpers.tpl                         (Day 4)
├── infra/
│   ├── ingress-nginx/
│   │   ├── values.yaml                              (Day 3)
│   │   └── README.md                                (Day 3)
│   ├── cert-manager/
│   │   ├── values.yaml                              (Day 3)
│   │   ├── clusterissuer-selfsigned-bootstrap.yaml  (Day 3)
│   │   ├── clusterissuer-selfsigned-ca.yaml         (Day 3)
│   │   └── certificate-ca.yaml                      (Day 3)
│   ├── sealed-secrets/
│   │   ├── values.yaml                              (Day 3)
│   │   └── README.md                                (Day 3)
│   ├── kube-prometheus-stack/
│   │   ├── values.yaml                              (Day 5)
│   │   └── dashboards/
│   │       ├── buyerchat-red.json                   (Day 5)
│   │       └── kubernetes-overview.json             (Day 5; chart-bundled, just doc'd)
│   ├── loki/
│   │   └── values.yaml                              (Day 5)
│   ├── tempo/
│   │   └── values.yaml                              (Day 5)
│   ├── argocd/
│   │   ├── values.yaml                              (Day 6)
│   │   └── README.md                                (Day 6)
│   └── argo-rollouts/
│       ├── values.yaml                              (Day 6)
│       └── README.md                                (Day 6)
├── argocd/
│   ├── app-of-apps/
│   │   └── root.yaml                                (Day 6)
│   └── apps/
│       ├── ingress-nginx.yaml                       (Day 6)
│       ├── cert-manager.yaml                        (Day 6)
│       ├── sealed-secrets.yaml                      (Day 6)
│       ├── kube-prometheus-stack.yaml               (Day 6)
│       ├── loki.yaml                                (Day 6)
│       ├── tempo.yaml                               (Day 6)
│       ├── argo-rollouts.yaml                       (Day 6)
│       └── buyerchat.yaml                           (Day 6)
├── policies/
│   ├── network/
│   │   ├── default-deny-app.yaml                    (Day 7)
│   │   ├── allow-ingress-to-buyerchat.yaml          (Day 7)
│   │   ├── allow-buyerchat-egress-dns.yaml          (Day 7)
│   │   └── allow-buyerchat-egress-https.yaml        (Day 7)
│   └── pss/
│       ├── ns-app-restricted.yaml                   (Day 7)
│       ├── ns-monitoring-restricted.yaml            (Day 7)
│       └── ns-controllers-baseline.yaml             (Day 7)
├── ci/
│   └── (workflow YAMLs symlinked into .github/workflows/) (Day 7)
├── .github/
│   └── workflows/
│       ├── lint.yaml                                (Day 7)
│       └── kind-smoke.yaml                          (Day 7, label-gated)
└── docs/
    ├── P3-SCOPE.md                                  (Day 1) ← TODAY
    ├── architecture.md                              (Day 7)
    ├── tradeoffs.md                                 (Day 7)
    ├── runbooks/                                    (Day 7)
    │   ├── argocd-out-of-sync.md
    │   ├── rollout-stuck.md
    │   ├── pod-crashloop.md
    │   └── cert-not-issued.md
    ├── retros/
    │   └── p3-week1.md                              (Day 7)
    ├── screenshots/                                 (Day 7)
    │   ├── argocd-tree.png
    │   ├── grafana-red.png
    │   ├── grafana-loki.png
    │   ├── grafana-tempo.png
    │   ├── rollouts-canary.png
    │   ├── prom-targets.png
    │   └── kubectl-pods.png
    └── diagnostics/
        └── p3-week1/
            ├── findings.md                          (Day 1) ← TODAY
            ├── task_plan.md                         (Day 1) ← TODAY
            ├── progress.md                          (appended daily) ← Day 1 entry today
            ├── HANDOFF.md                           (Day 7)
            └── final-verify.txt                     (Day 7)
```

---

## F. Verdict

```
[OK] — Phase 1 investigation complete.
Five Day-1 deliverables written. Toolchain partially present (docker
+ kubectl yes; helm + kind no; docker daemon not running). GHCR
package suspected private; resolved at 90% confidence to ship
imagePullSecrets via Sealed Secrets. Sixteen open questions resolved
inline at ≥80% confidence; one (Q-12: degraded-mode buyerchat boot)
flagged for Day 4 operator confirmation but proceeds by default.
Next: operator reviews this doc + P3-SCOPE.md, confirms scope, then
Day 2 begins with toolchain install + kind cluster bring-up.
```
