# devops-showcase — Interview Report

## What I built

A full Kubernetes platform running on a local kind cluster. The kind cluster runs on Docker — no VM, no cloud, no cost. It has ArgoCD for GitOps, Argo Rollouts for canary deploys, ingress-nginx for ingress, cert-manager for TLS, Sealed Secrets for secret management, and a full observability stack: Prometheus for metrics, Loki for logs, Tempo for traces, Grafana for dashboards.

The workload is buyerchat (Homesty.ai's AI chat product) running in degraded mode — no real database, so it returns 503 on health checks. That's intentional. The platform is what I'm showcasing, not the application.

---

## Why I built it

I wanted to understand Kubernetes from the inside out. Buyerchat ran on Vercel — serverless, managed. I didn't know what happened below the surface. How does a service get a TLS certificate? How does GitOps actually work in practice? What's the difference between a Deployment and a Rollout?

I read the docs, but the docs only get you so far. I needed to build it. The constraint: no budget. kind runs on Docker, uses Docker as the node, and works on any machine with Docker installed. Zero infrastructure cost.

---

## The hardest part — ArgoCD sync waves and dependency ordering

Getting 8 child Applications to sync in the right order wasn't straightforward. ArgoCD doesn't guarantee child app ordering by default. If cert-manager hasn't finished installing, the ClusterIssuer can't be created. If the ClusterIssuer isn't ready, TLS can't work.

I used `sync-wave` annotations on the Application resources. Wave 0: foundation (ingress-nginx, cert-manager, sealed-secrets, argo-rollouts). Wave 1: observability (prometheus, loki, tempo). Wave 2: workload (buyerchat). ArgoCD applies resources in order of their sync-wave annotation, lowest first.

The tricky part: sync-wave is an annotation on the ArgoCD Application CRD, not on the Kubernetes resources being deployed. I had to understand how ArgoCD reconciles its desired state against the actual cluster state.

---

## The second hardest part — Grafana dashboard auto-import

Grafana's Prometheus instance comes from kube-prometheus-stack and is pre-configured. If I want the buyerchat RED dashboard to show up in Grafana without manually creating a datasource, I need Grafana to auto-discover it.

The trick: label the ConfigMap that holds the dashboard JSON with `grafana_dashboard: "1"`. kube-prometheus-stack's Grafana is configured to scan for ConfigMaps with that label in any namespace and import them automatically. The dashboard appears without any manual datasource pointing.

This took a lot of digging to find. The kube-prometheus-stack documentation doesn't highlight this — it's buried in a Helm values option.

---

## The third hardest part — Sealed Secrets per-cluster key

Sealed Secrets encrypts secrets using a per-cluster public/private key pair. The controller generates this key on first install. The encrypted secrets can be committed to git (which is the point — you can have a GitOps workflow for secrets).

The catch: if you delete the cluster, the Sealed Secrets controller key is gone. You can't decrypt the sealed secrets anymore. They're permanent garbage.

For a showcase this is fine — the cluster is disposable. For production, you'd use HashiCorp Vault or ESO (External Secrets Operator) with a real secrets backend. I documented this tradeoff in `docs/tradeoffs.md`.

---

## What I'd change

**Add a smoke test that runs in CI** — the CI workflow validates manifests but doesn't actually bring up the cluster. A kind-based smoke test (gated on a PR label) would catch real failures. The CI workflow has the code commented out with a note.

**Add Argo Rollouts analysis templates** — the canary deploy currently auto-rolls back on error spike (a metric threshold), but it doesn't have custom metrics for analysis. Adding a proper AnalysisTemplate would make the canary more intelligent about when to proceed.

**Switch from self-signed to cert-manager ACME** — for production, you'd want Let's Encrypt to issue real certificates. The change is one line in the ClusterIssuer spec (swap `issuerRef.name: selfsigned-issuer` to `issuerRef.name: letsencrypt-prod`). I left it as self-signed because a local cluster can't reach Let's Encrypt's ACME servers.

---

## What I learned

**ArgoCD app-of-apps pattern** — one root Application watches a Git directory. That directory contains Application manifests for child apps. The root app creates the child apps, child apps manage the actual Kubernetes resources. This is GitOps done right.

**Argo Rollouts vs vanilla Deployment** — Rollout CRD wraps a Deployment and adds canary strategy. The controller manages the replica count progression (25% → 50% → 75% → 100%) and watches metrics for rollback decisions. A regular Deployment can't do this.

**kind networking** — kind creates a special Docker network for the cluster nodes. Because kind uses Docker containers as nodes, port mappings (`extraPortMappings` in the kind config) map host ports to container ports. ingress-nginx listens on host ports 80 and 443, which is how the browser reaches the cluster from the host machine.

**Helm lifecycle in CI** — `helm lint` validates chart syntax. `helm template` renders templates with values. `kubeconform` validates the rendered manifests against Kubernetes API schemas. You need all three: lint catches chart errors, template catches template errors, kubeconform catches Kubernetes API errors.

---

## Numbers that matter

- 8 ArgoCD child applications (1 root + 8 children)
- 8 platform components (ingress-nginx, cert-manager, sealed-secrets, argo-rollouts, prometheus, loki, tempo, argocd)
- 2 buyerchat replicas (PSS restricted, NetworkPolicy default-deny)
- 30s Prometheus scrape interval
- 3 observability pillars (metrics + logs + traces)
- `make up` brings up full stack in under 10 minutes

---

## For the interview

Be ready to explain:
- How kind differs from k3d/minikube (answer: Docker-as-node, no VM, most portable)
- ArgoCD app-of-apps vs standalone apps (answer: root app creates children, single GitOps entry point)
- Why sync waves (answer: dependency ordering — cert-manager before ClusterIssuer)
- Self-signed CA vs ACME tradeoffs (answer: local can't reach LE, production uses ACME)
- Sealed Secrets per-cluster key limitation (answer: cluster deletion = unrecoverable sealed secrets)

This project lives at: github.com/ykstorm/devops-showcase