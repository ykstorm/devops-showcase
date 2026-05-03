# P3 Week 1 — 7-Day Task Plan

**Locked:** 2026-05-03 (Day 1)
**Sprint:** P3 — DevOps Pipeline Showcase, Week 1
**Reference scope:** `docs/P3-SCOPE.md`
**Reference findings:** `docs/diagnostics/p3-week1/findings.md`

> Each day below has: **Goal**, **Deliverables**, **Acceptance
> criteria** (objective, falsifiable), **Daily commit message**, and
> **Risk / fallback**. Days are sized for ~3-5 hours of focused work
> each, leaving slack for the inevitable bring-up surprises.

---

## Day 1 — 2026-05-03 — Investigation + scope lock + skeleton (THIS COMMIT)

**Status:** in flight (this is it).

**Goal:** Producer the documentation contract that locks scope, the
investigation report that surfaces toolchain gaps and decision points,
and a minimal-viable repo skeleton (gitignore + README) that future
days build into.

**Deliverables (5):**

1. `docs/P3-SCOPE.md` — locked scope contract.
2. `docs/diagnostics/p3-week1/findings.md` — current state, toolchain
   inventory, 18 open questions resolved or escalated.
3. `docs/diagnostics/p3-week1/task_plan.md` — this file.
4. `docs/diagnostics/p3-week1/progress.md` — Day 1 entry (append-only
   from here on).
5. `.gitignore` + `README.md` skeleton at repo root.

**Acceptance criteria:**

- [ ] All 5 deliverables exist and are non-empty.
- [ ] `docs/P3-SCOPE.md` enumerates: success criteria (10 items),
      anti-scope, daily cadence table, anti-touch list.
- [ ] `findings.md` documents toolchain present + missing, GHCR probe
      result, and ≥10 resolved questions with confidence percentages.
- [ ] `task_plan.md` has 7 day-rows below with acceptance criteria
      each.
- [ ] `progress.md` has exactly one entry (Day 1).
- [ ] `git init` + initial commit lands on a `p3-day1-scope` branch
      (or `main` if operator prefers; default `main` for Day 1).
- [ ] **No installs.** No `helm`, no `kind`, no `docker pull`, no
      `npm`. The directory state must be re-creatable by re-running
      this same plan.

**Daily commit message (HEREDOC):**

```
docs(p3): day 1 — scope lock + investigation + skeleton

Locks the elevated P3 sprint scope: 7-day platform-engineering
showcase deploying ghcr.io/ykstorm/buyerchat to a local kind cluster
through ArgoCD app-of-apps + Argo Rollouts + Sealed Secrets +
ingress-nginx + cert-manager + Prometheus + Loki + Tempo + Network
Policies + Pod Security Standards.

Read-only sprint phase. No installs, no cluster mutations, no docker
pulls. Documentation + skeleton only.

Toolchain inventory: docker installed (daemon stopped), kubectl
v1.28.2 installed, helm + kind absent — Day 2 preconditions list
captures the install steps.

GHCR probe: anonymous bearer returns 404 on
ghcr.io/ykstorm/buyerchat:latest, consistent with the package being
private. Day 4 wires imagePullSecrets via a Sealed Secret.

Resolved 18 open questions at ≥80% confidence (cluster topology,
ingress class, TLS strategy, GitOps shape, secrets strategy, rollout
strategy, PSS levels, NetworkPolicy posture, etc.). Q-12 (buyerchat
degraded-mode boot vs in-cluster Postgres) flagged for Day 4
operator review; default proceeds with degraded mode.

Discipline checklist applied: §9, §10, §13, §14, §15.
```

**Risk / fallback:** Day 1 has no external dependencies. Worst case
is the operator pushes back on scope — that's *exactly* what this
day's deliverables exist to surface.

---

## Day 2 — Cluster bring-up + restricted-PSS namespace + raw buyerchat manifests + NetworkPolicies (LOCKED 2026-05-04)

**Goal:** A reproducible, declarative kind cluster (single-node, Calico
CNI) with the `buyerchat` namespace running the
`ghcr.io/ykstorm/buyerchat:sha-8560cb3` image under `restricted` PSS,
fronted by a default-deny + explicit-allow NetworkPolicy posture, all
applied via raw YAML manifests (no Helm yet — Day 3). Smoke test via
`kubectl port-forward` (no Ingress yet — Day 3).

**Pre-conditions (operator-resolved before Day 2 starts):**

- Docker Desktop running (`docker info` returns clean).
- `helm` v3.15+ on PATH (not used Day 2; needed Day 3 onward).
- `kind` v0.23+ on PATH.
- (GHCR package confirmed public; no PAT required.)

**Constraints (locked):**

- Restricted PSS profile via namespace labels:
  `pod-security.kubernetes.io/enforce: restricted` (+ audit + warn).
  Deployment securityContext satisfies it: no root, no privileged,
  drop ALL capabilities, readOnlyRootFilesystem with emptyDir for
  writable paths Next.js requires (`/tmp`, `/app/.next/cache`).
- ImagePullPolicy: `IfNotPresent`. Pre-load the image into kind via
  `kind load docker-image` to avoid registry hits during pod start.
- NO real secrets committed. Stub env in plain `Secret` for Day 2;
  Day 3 replaces it with a SealedSecret.
- NO Helm Day 2 — raw YAMLs only.
- NO Ingress controller Day 2. Smoke test via `kubectl port-forward`.

**Deliverables:**

1. `kind/cluster.yaml` — single-node Cluster CR;
   `disableDefaultCNI: true`; podSubnet `192.168.0.0/16` aligned
   with the Calico Installation CR.
2. `kind/calico/installation.yaml` — Calico Installation + APIServer
   CRs (operator-driven install).
3. `kind/calico/README.md` — pinned tigera-operator manifest URL +
   Calico version + why Calico over kindnet.
4. `manifests/buyerchat/00-namespace.yaml` — `buyerchat` ns with PSS
   labels.
5. `manifests/buyerchat/10-secret-stub.yaml` — stub env (placeholder
   values; Day 3 replaces with SealedSecret).
6. `manifests/buyerchat/20-deployment.yaml` — restricted-compliant
   Deployment, image pinned to `:sha-8560cb3`, `imagePullPolicy:
   IfNotPresent`, emptyDir mounts for `/tmp` + `/app/.next/cache`.
7. `manifests/buyerchat/30-service.yaml` — ClusterIP :3000.
8. `manifests/buyerchat/40-netpol-default-deny.yaml` — deny-all
   ingress + egress in `buyerchat` ns.
9. `manifests/buyerchat/41-netpol-allow-dns-egress.yaml` — egress to
   kube-dns:53 (UDP+TCP).
10. `manifests/buyerchat/42-netpol-allow-internal-ingress.yaml` —
    ingress allowed from same-namespace pods.
11. `scripts/up.ps1` — PowerShell-native lifecycle: precheck → kind
    create → Calico install → image preload → manifest apply →
    Deployment Available wait → smoke-test recipe printed.
12. `scripts/down.ps1` — `kind delete cluster --name devops-showcase`
    (gated behind interactive confirm or `-Force` flag).
13. Day-2 progress.md entry prepended.

**Acceptance criteria (operator-side after `scripts\up.ps1` runs cleanly):**

1. `kind get clusters` lists `devops-showcase`.
2. `kubectl get pods -A` shows `calico-*` pods Running, no `kindnet-*`.
3. `kubectl get ns buyerchat -o jsonpath='{.metadata.labels}'`
   includes `pod-security.kubernetes.io/enforce: restricted`.
4. `kubectl get pods -n buyerchat` shows buyerchat pod Running.
5. `kubectl get networkpolicies -n buyerchat` lists three policies:
   `default-deny`, `allow-dns-egress`, `allow-internal-ingress`.
6. `kubectl port-forward -n buyerchat svc/buyerchat 3000:3000` succeeds
   and `curl http://localhost:3000/api/healthcheck` returns ANY HTTP
   response (200 or 503).
7. `scripts\down.ps1` cleanly tears down the cluster.
8. `git status` is clean after the final Day-2 commit.

**Commit messages (one per logical step):**

1. `chore(scope): Day-1 review notes locked` — the 4 doc edits.
2. `feat(kind): single-node cluster config with Calico CNI` — kind/.
3. `feat(k8s): buyerchat namespace + restricted PSS + raw manifests` — manifests/buyerchat/ except netpols.
4. `feat(netpol): default-deny + DNS + internal ingress allow rules` — manifests/buyerchat/4{0,1,2}*.
5. `chore(scripts): up/down lifecycle scripts` — scripts/.
6. `docs(p3-day2): progress entry + acceptance criteria capture` — progress.md.

**Risk / fallback:**
- **Risk:** Buyerchat image runs as USER 0 in its Dockerfile →
  `runAsNonRoot: true` blocks startup → CrashLoopBackOff.
  → Mitigation: Day 2 sets `runAsUser: 1001` explicitly + `runAsGroup:
  1001`. If the image still won't boot under restricted PSS, fall back
  to `baseline` and document as acceptance-criterion-3 [PARTIAL].
- **Risk:** Next.js standalone needs writable cache paths beyond
  `/tmp` and `/app/.next/cache`. → emptyDir mounts cover the common
  cases; if more are needed, add as discovered.
- **Risk:** Calico tigera-operator install order — Installation CR
  applied before operator Deployment is Ready → CR rejected.
  → `up.ps1` waits for `tigera-operator` Deployment Available before
  applying the Installation CR.
- **Risk:** Operator's Docker Desktop / helm / kind not installed
  (current state at Day-2 start). → `up.ps1` precheck surfaces
  exactly what's missing and exits with actionable message.

---

## Day 3 — Foundation infra (ingress-nginx + cert-manager + sealed-secrets)

**Goal:** TLS-terminating ingress and the secrets-management primitive
needed by Day 4. All three controllers installed via Helm with values
files committed to `infra/`. Self-signed CA Issuer issues a working
cert for a smoke-test ingress.

**Deliverables:**

1. `infra/ingress-nginx/values.yaml` + `infra/ingress-nginx/README.md`
   (one-line install command).
2. `infra/cert-manager/values.yaml`,
   `infra/cert-manager/clusterissuer-selfsigned-bootstrap.yaml`
   (the bootstrap selfSigned issuer used to issue the CA cert),
   `infra/cert-manager/clusterissuer-selfsigned-ca.yaml`
   (the CA-backed issuer that everything else uses),
   `infra/cert-manager/certificate-ca.yaml`.
3. `infra/sealed-secrets/values.yaml` + `infra/sealed-secrets/README.md`.
4. `scripts/seal-secret.sh` — wraps `kubeseal --controller-name
   sealed-secrets --controller-namespace sealed-secrets --format
   yaml` with sane defaults.
5. `scripts/install-foundation.sh` — Day-3 installer (helm install
   for each of the three, in dependency order). Will be retired
   Day 6 when ArgoCD takes over.
6. README.md — Day-3 section.
7. Daily progress.md entry.

**Acceptance criteria:**

- [ ] `kubectl get pods -n ingress-nginx` shows controller `Running`.
- [ ] `kubectl get pods -n cert-manager` shows controller + webhook +
      cainjector all `Running`.
- [ ] `kubectl get clusterissuer` shows two issuers (`selfsigned-
      bootstrap`, `selfsigned-ca`), both `Ready: True`.
- [ ] `kubectl get pods -n sealed-secrets` shows controller `Running`.
- [ ] Smoke test: a temporary `Certificate` resource resolves to a
      `tls.crt`/`tls.key` `Secret` within 30s.
- [ ] Smoke test: `echo -n "hello" | kubectl create secret generic
      smoke --dry-run=client --from-file=val=/dev/stdin -o yaml |
      kubeseal ... > smoke-sealed.yaml` produces a valid
      SealedSecret YAML; `kubectl apply` of that file produces a
      `Secret` containing `hello`.

**Daily commit message:**

```
feat(p3): day 3 — ingress-nginx + cert-manager + sealed-secrets

ingress-nginx installed via helm (chart values in infra/); cert-
manager self-signed CA ClusterIssuer issuing certs from a cluster-
local CA (bootstrap → ca chain); sealed-secrets controller installed,
kubeseal wrapper at scripts/seal-secret.sh.

Smoke tests passing: cert issued in <30s; SealedSecret round-trip
encrypts/decrypts.

ACME swap is a one-line ClusterIssuer change, documented in tradeoffs
on Day 7.
```

**Risk / fallback:**
- **Risk:** cert-manager webhook race on fresh install (cert-manager
  webhook gets requests before its own cert is issued). → Standard
  fix: install order: chart → `kubectl wait
  --for=condition=Available deploy/cert-manager-webhook -n
  cert-manager --timeout=120s` → then apply ClusterIssuer.
- **Risk:** Sealed Secrets controller key generation takes ~30s on
  first install. → Wait for `Deployment/sealed-secrets-controller`
  Available before sealing anything.

---

## Day 4 — Buyerchat workload (Helm chart + Argo Rollouts CRD)

**Goal:** A deployable Helm chart at `helm/buyerchat/` that uses Argo
Rollouts' `Rollout` CRD instead of a vanilla `Deployment`. `helm
template` renders. `helm install` puts the workload up. Pod boots,
healthcheck returns 503 (degraded — see findings.md Q-12). Argo
Rollouts controller is installed today (Day 6 only adds it to ArgoCD's
purview); without the controller, the `Rollout` CRD is not yet
known.

**Pre-conditions:**

- Argo Rollouts controller installed (added to Day 4 install order;
  ArgoCD adopts it Day 6).
- GHCR PAT supplied by operator if image is private (per findings
  Q-12).

**Deliverables:**

1. `infra/argo-rollouts/values.yaml` + install (today, will be ArgoCD-
   managed Day 6).
2. `helm/buyerchat/Chart.yaml` (version 0.1.0, appVersion matching
   the SHA from buyerchat-p1 Day 6 if available, else `latest`).
3. `helm/buyerchat/values.yaml` — production-shaped defaults.
4. `helm/buyerchat/values.demo.yaml` — overrides for the kind demo
   (replicas=2, fake DATABASE_URL via SealedSecret reference).
5. `helm/buyerchat/templates/`:
   - `_helpers.tpl`
   - `rollout.yaml` (canary, 4 steps: 25/50/75/100, no analysis yet)
   - `service.yaml` (ClusterIP :3000)
   - `ingress.yaml` (TLS via cert-manager Certificate annotation)
   - `sealedsecret.yaml` (placeholder values; real seal happens
     locally and gets committed encrypted)
6. `helm/buyerchat/README.md` — chart usage.
7. README.md — Day-4 section.
8. Daily progress.md entry.

**Acceptance criteria:**

- [ ] `helm lint helm/buyerchat` passes.
- [ ] `helm template helm/buyerchat -f helm/buyerchat/values.demo.yaml |
      kubeconform -strict -ignore-missing-schemas` passes.
- [ ] `helm install buyerchat helm/buyerchat -f
      helm/buyerchat/values.demo.yaml -n app` succeeds.
- [ ] `kubectl get rollout buyerchat -n app` shows `Healthy`.
- [ ] `kubectl get pods -n app -l app=buyerchat` shows 2 `Running`
      pods.
- [ ] `kubectl exec -n app deploy/... -- wget -qO-
      http://localhost:3000/api/healthcheck` returns HTTP 503 (per
      findings Q-12 degraded-mode expectation) — and the body is the
      503 JSON shape from `buyerchat-p1` Day 6 (`{ "status":
      "degraded", ... }`).
- [ ] `https://buyerchat.local.devops-showcase.dev/` (via /etc/hosts)
      returns a 200 from the Next.js page (the page renders even
      though the API route is degraded).

**Daily commit message:**

```
feat(p3): day 4 — buyerchat helm chart + argo-rollouts canary

helm/buyerchat/ chart deploys ghcr.io/ykstorm/buyerchat:latest as an
Argo Rollouts canary (25/50/75/100 step plan, no analysis template
yet — Day 6 stretch). Service + Ingress + placeholder SealedSecret
included. argo-rollouts controller installed under infra/.

Demo runs in degraded mode (DB-less): /api/healthcheck returns 503;
front-end page serves 200. Documented in findings Q-12.
```

**Risk / fallback:**
- **Risk:** GHCR private + no PAT supplied. → Day 4 [BLOCKED]; chart
  ships with `imagePullSecrets` pointing at `ghcr-pull` Secret that
  doesn't yet exist; operator supplies PAT next session.
- **Risk:** buyerchat image won't start without Sentry DSN / other
  envs. → Verify which envs are required vs optional (image source
  in buyerchat-p1; `src/lib/env.ts` if it exists would tell us).
  Required-but-missing → degrade gracefully or set a dummy.
- **Risk:** Argo Rollouts CRD v1.6+ syntax differs from older docs.
  → Pin to a specific Rollouts chart version (1.7.x at time of
  writing) and document.

---

## Day 5 — Observability (Prometheus + Loki + Tempo + dashboards)

**Goal:** Three-pillar observability live on the cluster. Buyerchat
appears as a scraped target; logs appear in Loki; a sample trace
appears in Tempo. RED-metrics dashboard pre-wired in Grafana.

**Deliverables:**

1. `infra/kube-prometheus-stack/values.yaml` (Prometheus retention
   24h on a kind cluster, Grafana admin pwd via SealedSecret,
   ServiceMonitor selector matchLabels for our charts).
2. `infra/kube-prometheus-stack/dashboards/buyerchat-red.json` — 3
   panels: req rate / 5xx rate / p95 latency. ConfigMap-imported via
   the `grafana_dashboard: "1"` label trick.
3. `infra/loki/values.yaml` — `loki-stack` chart, single-binary mode,
   Promtail enabled.
4. `infra/tempo/values.yaml` — monolithic tempo, OTLP receiver on
   :4317.
5. `helm/buyerchat/templates/servicemonitor.yaml` (gated behind
   `serviceMonitor.enabled: true` value).
6. `scripts/install-observability.sh` (retired Day 6 when ArgoCD
   takes over).
7. README.md — Day-5 section + screenshot placeholders.
8. Daily progress.md entry.

**Acceptance criteria:**

- [ ] `kubectl get servicemonitor -n app` shows the buyerchat SM.
- [ ] Prometheus targets page (`/targets`) shows `buyerchat` target
      `UP`.
- [ ] Grafana loads at
      `https://grafana.local.devops-showcase.dev/`, admin login
      works (pwd from SealedSecret).
- [ ] "Buyerchat — RED" dashboard auto-imports and renders 3 panels
      with non-empty data (5xx panel will show non-zero — that's the
      degraded-mode signal).
- [ ] Loki Explore tab shows live pod logs from `app/buyerchat-*`.
- [ ] Tempo Explore tab — a manual `kubectl port-forward + curl`
      with a `traceparent` header against buyerchat returns a span
      visible in Tempo. (If buyerchat doesn't natively emit OTLP,
      stretch — document the gap and skip the trace assertion;
      RED + Loki are sufficient.)

**Daily commit message:**

```
feat(p3): day 5 — observability stack (prometheus + loki + tempo)

kube-prometheus-stack + loki-stack + tempo-monolithic installed via
helm under infra/. ServiceMonitor wired into helm/buyerchat for
prometheus scraping. RED dashboard auto-imported to grafana via
ConfigMap label trick.

Tempo trace assertion is best-effort: if the buyerchat image does
not emit OTLP traces natively, this is documented as a v1.0 stretch
(adding an OpenTelemetry instrumentation layer to the Next.js app
would be a buyerchat-side sprint, not P3-side).
```

**Risk / fallback:**
- **Risk:** kube-prometheus-stack default values request a lot of
  storage. → Kind PVC backed by host-path; capped retention to 24h.
  Document.
- **Risk:** Tempo trace ingestion silent on first install. → Skip;
  RED dashboards alone are demo-sufficient.

---

## Day 6 — GitOps (ArgoCD + app-of-apps)

**Goal:** ArgoCD becomes the single source of truth for cluster state.
Every controller / chart installed Day 3-5 gets re-expressed as an
ArgoCD `Application` under `argocd/apps/`, registered under a single
root app-of-apps `Application`. Day-3 / Day-5 install scripts get
deleted in this commit (or noted as deprecated). A test commit on a
branch (image tag bump in `helm/buyerchat/values.demo.yaml`) reaches
the cluster purely via ArgoCD's auto-sync.

**Deliverables:**

1. `infra/argocd/values.yaml` — Helm install values (ingress on,
   server `--insecure` flag fine for kind, admin pwd via
   SealedSecret).
2. `argocd/app-of-apps/root.yaml` — one `Application`, source pointing
   at `argocd/apps/`, sync policy automated + prune + self-heal.
3. `argocd/apps/*.yaml` — eight Applications, one per chart we
   installed Day 3-5 plus buyerchat. All `automated: { prune: true,
   selfHeal: true }`, sync waves where order matters
   (`argocd.argoproj.io/sync-wave: "0"` for foundational, `"1"` for
   monitoring, `"2"` for workload).
4. `scripts/install-argocd.sh` — one-time-use bootstrap (replaces
   Day 3 + Day 5 install scripts which get deleted). After this
   runs once and the root app-of-apps is applied, ArgoCD owns
   everything.
5. `scripts/port-forward.sh` — convenience: `argocd-server` :8080,
   `grafana` :3000.
6. README.md — Day-6 section.
7. Daily progress.md entry.

**Acceptance criteria:**

- [ ] `kubectl get applications -n argocd` shows 1 root + 8 child
      apps, all `Synced: Synced` + `Health: Healthy`.
- [ ] `https://argocd.local.devops-showcase.dev/` loads, admin login
      works.
- [ ] App-of-apps tree visible in UI; root app shows children
      correctly nested.
- [ ] **GitOps round-trip test:** create branch, bump
      `helm/buyerchat/values.demo.yaml` image tag, merge, wait ≤3
      min → ArgoCD detects + Argo Rollouts kicks off canary →
      `kubectl get rollout buyerchat -n app -w` shows step
      progression → final state Healthy.
- [ ] Day-3 + Day-5 install scripts deleted from `scripts/` (or
      moved to `scripts/_deprecated/` with a README explaining
      why).

**Daily commit message:**

```
feat(p3): day 6 — argocd app-of-apps gitops

ArgoCD installed; one root Application points at argocd/apps/, which
holds 8 per-component Applications (ingress-nginx, cert-manager,
sealed-secrets, kube-prometheus-stack, loki, tempo, argo-rollouts,
buyerchat). All auto-sync + prune + self-heal. Sync waves order
foundational → observability → workload.

Round-trip test: image tag bump merged to main → ArgoCD detected in
~90s → Argo Rollouts ran canary 25/50/75/100 → final state Healthy.

Day 3 + Day 5 install scripts retired; ArgoCD is now the only
mutator of cluster state.
```

**Risk / fallback:**
- **Risk:** ArgoCD's first reconcile loops fight with Helm's
  in-cluster ownership annotations. → Use `helm uninstall` of the
  Day-3/Day-5 releases first, *then* let ArgoCD adopt. Document.
- **Risk:** Sealed Secret YAMLs committed Day 3/4 reference a
  controller key that's per-cluster. After `kind delete cluster +
  kind create cluster`, the new controller has a different key and
  the committed sealed secrets won't decrypt. → Document. Mitigation:
  back up the sealed-secrets controller key
  (`kubectl get secret -n sealed-secrets sealed-secrets-keyXXXX -o
  yaml > .secrets/sealed-secrets-key.yaml`) and have
  `bootstrap.sh` restore it if present. Adds a known one-time setup
  step but makes the demo cluster reproducible across rebuilds.

---

## Day 7 — Policy + CI + retro + screenshots

**Goal:** Defense-in-depth (NetworkPolicy + PSS), CI safety net (lint
on every PR), and the documentation that makes the repo recruiter-
legible (architecture diagram, tradeoffs, runbooks, retro,
screenshots).

**Deliverables:**

1. `policies/network/*.yaml` — default-deny + 3 explicit allows for
   the `app` namespace (ingress in, DNS out, HTTPS egress to allow
   list).
2. `policies/pss/*.yaml` — namespace labels enforcing PSS levels per
   findings Q-9.
3. `helm/buyerchat/templates/networkpolicy.yaml` — chart-level
   NetworkPolicy (alternative to the cluster-level one in
   `policies/`; the chart's NP is `enabled: true` by default in
   `values.yaml`).
4. `argocd/apps/policies.yaml` — ArgoCD app for `policies/`.
5. `.github/workflows/lint.yaml` — helm-lint + kubeconform + kubeval
   + YAML lint on every PR + push to main.
6. `.github/workflows/kind-smoke.yaml` — label-gated end-to-end
   smoke (skipped by default).
7. `Makefile` — `up`, `down`, `verify`, `lint`, `screenshots`,
   `port-forward` targets.
8. `docs/architecture.md` — request-flow + GitOps-flow + obs-flow
   mermaid diagrams.
9. `docs/tradeoffs.md` — every "why X not Y" decision from
   `findings.md` Q-1 through Q-T condensed for a recruiter audience.
   Must include the **SHA-pinning policy** as a one-line entry next
   to the Calico-vs-kindnet entry: "image.tag pinned to a SHA digest,
   never `:latest` — reproducible deploys, immutable referent, no
   surprise rollouts when CI rebuilds."
10. `docs/runbooks/argocd-out-of-sync.md`,
    `docs/runbooks/rollout-stuck.md`,
    `docs/runbooks/pod-crashloop.md`,
    `docs/runbooks/cert-not-issued.md` — four one-pagers.
11. `docs/screenshots/` — 7 PNGs captured from a live `make up`.
12. **Cross-repo cleanup ticket (one-line entry, tracked here, not
    actioned in this repo):** the buyerchat-p1 repo's `docker.yml`
    workflow does NOT publish `:latest` even though the buyerchat
    README + `buyerchat-p1/docs/DOCKER.md` instruct readers to
    `docker pull ghcr.io/ykstorm/buyerchat:latest`. Default fix
    (option a): patch `buyerchat-p1/.github/workflows/docker.yml` to
    add `:latest` on every push to `main`. Fallback (option b):
    update the buyerchat-p1 README + DOCKER.md to remove the
    `:latest` instruction. Owned by a separate buyerchat-p1 sprint;
    P3 Day 7 just records the ticket existence + recommended option.
13. `docs/diagnostics/p3-week1/HANDOFF.md` — sprint-close artifact
    mirroring the structure of
    `buyerchat-p1/docs/diagnostics/p1-week1/HANDOFF.md` (verify-
    state baseline table, anti-touch list, queued items).
14. `docs/diagnostics/p3-week1/final-verify.txt` — captured stdout
    of `make verify` from a clean run.
15. `docs/retros/p3-week1.md` — per AGENT_DISCIPLINE §16. Two
    paragraphs: what worked / what surprised, what to do
    differently.
16. README.md — final architecture diagram + 5-step quickstart with
    screenshots inline.
17. Daily progress.md entry (final).

**Acceptance criteria:**

- [ ] `kubectl run rogue --image=alpine --rm -it -n app -- wget
      http://buyerchat:3000` is **denied** (NetworkPolicy block).
- [ ] `kubectl run pinger --image=alpine --rm -it -n ingress-nginx
      -- wget http://buyerchat.app.svc.cluster.local:3000` works.
- [ ] `kubectl get ns -L pod-security.kubernetes.io/enforce` shows
      the right enforce levels per Q-9.
- [ ] CI run on the Day-7 PR is green (helm-lint + kubeconform pass
      on every chart + kubeval passes on every static manifest).
- [ ] `make verify` runs without error from a clean shell.
- [ ] All 7 screenshots present and non-zero-byte.
- [ ] `make up` end-to-end on a fresh laptop completes in ≤ 10 min
      (operator-timed; record in HANDOFF.md).
- [ ] All 10 success criteria from `P3-SCOPE.md` §4 pass.
- [ ] `docs/retros/p3-week1.md` exists, two paragraphs, every claim
      SHA-cited.

**Daily commit message:**

```
feat(p3): day 7 — policies + CI + retro + screenshots (sprint close)

NetworkPolicy default-deny on app namespace + 3 explicit allow rules.
Pod Security Standards labels: restricted on app/argocd/monitoring,
baseline on controller namespaces. Helm chart ships its own NP
template (enabled by default).

CI lint workflow runs helm-lint + kubeconform + kubeval + yaml-lint
on every PR + push to main. Kind smoke workflow gated behind a PR
label (slow runner; off by default).

Makefile: up / down / verify / lint / screenshots / port-forward.

Documentation complete: architecture.md (mermaid diagrams),
tradeoffs.md (decision log condensed), 4 runbooks, 7 screenshots,
HANDOFF.md (verify-state table + anti-touch list), final-verify.txt
(capture of make verify), retro (per AGENT_DISCIPLINE §16).

Sprint summary: 7 daily commits across 7 days, 0 [BLOCKED] days, 1
[PARTIAL] (Day 5 Tempo trace assertion deferred per risk plan), all
10 P3-SCOPE §4 success criteria passing.
```

**Risk / fallback:**
- **Risk:** PSS `restricted` on `app` namespace breaks the
  buyerchat pod (e.g., needs to bind a privileged port, runs as
  root). → Fall back to `baseline` on `app` namespace; document
  what would need to change in the buyerchat image to run under
  `restricted` (a v1.0 buyerchat-side sprint). Status: [PARTIAL].
- **Risk:** Screenshots can't be captured because `make up` shows
  intermittent failures on the operator's machine. → Capture
  whatever runs cleanly; mark missing ones as TODO; ship Day 7 as
  [PARTIAL].

---

## Cross-cutting

### Verify-state baseline table (filled progressively)

| Day | SHA  | All criteria? | Notes |
|-----|------|---------------|-------|
| 1   | TBD  | -             | Day 1 has its own 6 criteria, not the §4 sprint criteria. |
| 2   | TBD  | -             | |
| 3   | TBD  | -             | |
| 4   | TBD  | -             | |
| 5   | TBD  | -             | |
| 6   | TBD  | -             | |
| 7   | TBD  | -             | All 10 §4 criteria. |

### Per-day discipline checklist application

The discipline sections that apply each day (from `findings.md` §C
and AGENT_DISCIPLINE):

- **Every day:** §9 (gates), §10 (report-back), §13 (handoff —
  `progress.md` updated), §14 (verdict), §15 (autonomous decisions
  documented in commit body).
- **Day 4+:** §11 (sub-agents) if any are spawned; restate scope.
- **Day 7 only:** §16 (retro).
- **Application-layer rules §1-8:** **n/a** for this sprint.
  Buyerchat is consumed as an opaque image; we don't touch its
  source. The only §-rule that maps imperfectly is §7 (schema
  write provenance) — its spirit is "don't write trust-bearing
  values without provenance" — which the Sealed Secrets workflow
  honors at a different layer.

### When to escalate to operator

Any of these triggers a mid-sprint pause and chat report with
`[NEEDS DECISION]`:

1. GHCR turns out to be public after all (re-decide imagePullSecret
   strategy at Day 4 kickoff).
2. Operator wants real local Postgres for buyerchat (re-scope Q-12).
3. Day-N criteria fail and the fallback path also fails.
4. A discovered missing dependency requires paid spend (e.g., Docker
   Desktop license needs upgrade for "non-personal use" — this is a
   real Docker Inc. licensing wrinkle that some operators trip on).
5. Any time `kind delete cluster` or `helm uninstall` is the
   recommended next step (per AGENT_DISCIPLINE §15: destructive ops
   always escalate).

### Closing

This plan is the contract for week 1. Day-N deviations update both
this file and `progress.md` in the same commit. End-of-week 1, the
plan transitions to a "delivered" archive state and Week 2 (if any)
gets its own plan.
