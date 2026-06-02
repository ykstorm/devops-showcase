# Stackup

**Production-grade Kubernetes on your laptop. ArgoCD + Argo Rollouts + Prometheus + Loki + Tempo + Grafana. `make up` in 10 minutes. Free.**

[![CI](https://github.com/ykstorm/stackup/actions/workflows/ci.yml/badge.svg)](https://github.com/ykstorm/stackup/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Live Grafana snapshot](https://img.shields.io/badge/grafana-snapshot-orange)](https://snapshots.raintank.io/dashboard/snapshot/stackup-demo)

Live Grafana snapshot from a real `make up` run: **[snapshots.raintank.io/dashboard/snapshot/stackup-demo](https://snapshots.raintank.io/dashboard/snapshot/stackup-demo)**

---

## Why Stackup

Production-grade Kubernetes costs $200+/month minimum on managed cloud — just to learn. Stackup runs the full production stack on kind, on your laptop, for free.

What "full production stack" means: a real ArgoCD app-of-apps with 8 child applications, Argo Rollouts canary progressive delivery, Prometheus + Loki + Tempo observability wired together (metrics → logs → traces, drill-through from any panel), cert-manager TLS, Sealed Secrets encrypted in git, Calico NetworkPolicy enforcement, and Pod Security Standards `restricted` on every workload namespace.

The buyerchat workload deliberately runs degraded (no DB). That's intentional. The cluster is the demo — not the app.

---

## What's in the box

| Layer | Component | What it does |
|---|---|---|
| **Cluster** | kind on Docker | 3-node K8s in containers |
| **CNI** | Calico | NetworkPolicy enforcement |
| **GitOps** | ArgoCD (app-of-apps) | One root app manages 8 children; automated sync + prune + self-heal |
| **Progressive delivery** | Argo Rollouts | Canary 25→50→75→100%, auto-rollback on error spike |
| **Ingress** | ingress-nginx | TLS termination, hostPort 80/443 |
| **TLS** | cert-manager | Self-signed ClusterIssuer (swap to ACME in one line for prod) |
| **Secrets** | Sealed Secrets | Encrypted secrets in git, decrypted in-cluster |
| **Metrics** | kube-prometheus-stack | Prometheus + Alertmanager + Grafana, RED dashboards pre-imported |
| **Logs** | Loki + Promtail | Pod stdout → Loki → Grafana Explore |
| **Traces** | Tempo (monolithic) | OTLP traces from workloads |
| **Workload demo** | buyerchat Helm chart | Next.js app — demonstrates the cluster, not a production app |
| **Hardening** | PSS `restricted` + NetworkPolicy `default-deny` | Zero-trust on workload namespaces |

---

## 10-minute quickstart

```bash
# Prerequisites: docker (≥4.30), kind (≥0.22), helm (≥3.15), kubectl (≥1.30), make
git clone https://github.com/ykstorm/stackup && cd stackup

make up
```

Add to `/etc/hosts` (Windows: `C:\Windows\System32\drivers\etc\hosts`):

```
127.0.0.1 buyerchat.local.stackup.dev
127.0.0.1 grafana.local.stackup.dev
127.0.0.1 argocd.local.stackup.dev
127.0.0.1 prometheus.local.stackup.dev
```

Then open:

- **[https://buyerchat.local.stackup.dev](https://buyerchat.local.stackup.dev)** — workload, returns 503 degraded (no DB — expected)
- **[https://grafana.local.stackup.dev](https://grafana.local.stackup.dev)** — RED metrics + Loki logs + Tempo traces
- **[https://argocd.local.stackup.dev](https://argocd.local.stackup.dev)** — GitOps tree of 8 child apps

**First-run timing:**
- Docker image pulls: ~3 min
- ArgoCD sync (8 child apps): ~5 min
- TLS cert minting: ~1 min
- Workload + canary ready: ~1 min
- **Total: ~10 min**

Subsequent runs (images cached): ~3 min. `make down` to tear down.

---

## What it actually shows you

Push a commit that bumps `helm/buyerchat/values.yaml` image.tag. ArgoCD notices. Argo Rollouts applies the new Rollout resource. Watch:

```bash
kubectl argo rollouts get rollout buyerchat -n app --watch
```

The canary scales to 25% replicas. Prometheus watches error rate for 60 seconds. If clean, advances to 50%. Then 75%. Then 100%. If error rate spikes, automatic rollback. This is the pattern Lyft and Netflix run in production. Running on your laptop. Free.

Open Grafana. Click a P99 latency spike in the RED dashboard. The panel deep-links into Loki Explore, scoped to the same time window. Find the slow request log line, click the `trace_id`, land in Tempo with the full span tree of that request. Three observability tools, one shared trace context, no manual correlation.

---

## Architecture

```mermaid
graph TD
    Dev[Developer machine] -->|kind create cluster| Kind[kind cluster<br/>3 Docker nodes]
    Kind --> CP[Control plane]
    Kind --> W1[Worker 1]
    Kind --> W2[Worker 2]
    CP --> Argo[ArgoCD]
    Argo --> Apps[8 child apps]
    Apps --> Rollout[Argo Rollouts CRD]
    Rollout --> Pods[Canary pods]
    Pods --> Prom[Prometheus]
    Pods --> LokiL[Loki]
    Pods --> TempoT[Tempo]
    Prom --> Graf[Grafana]
    LokiL --> Graf
    TempoT --> Graf
    W1 --> Calico1[Calico CNI]
    W2 --> Calico2[Calico CNI]
```

For full topology + sequence diagrams, see [docs/architecture.md](docs/architecture.md).

---

## When to use Stackup and when not to

| You want this | Use |
|---|---|
| Learn production K8s patterns by running them, on your laptop, free | Stackup |
| Production cluster with managed control plane | AWS EKS / GCP GKE / Azure AKS |
| Quick smoke-test of one Helm chart | k3d or Kind directly |
| Single-binary, container-orchestration-lite | Tilt, Earthly |
| Hosted Kubernetes dev environment with collaboration | Devbox, Coder |

Stackup is for "I want to live inside ArgoCD and Argo Rollouts for two hours and learn what they actually do" — not for "I need a quick dev cluster." If you don't care about GitOps + canary deploys + observability all together, use a simpler tool.

It's also not a productionizer. It gives you the shape of production. You still need DR, backups, on-call rotation, image signing, etc.

---

## How it compares

| | Stackup | Minikube | k3d | Tilt | Skaffold |
|---|---|---|---|---|---|
| Multi-node | ✅ | partial | ✅ | n/a | n/a |
| NetworkPolicy works (CNI enforces) | ✅ Calico | partial | ❌ | n/a | n/a |
| GitOps included | ✅ ArgoCD | ❌ | ❌ | ❌ | ❌ |
| Progressive delivery + auto-rollback | ✅ Argo Rollouts | ❌ | ❌ | ❌ | ❌ |
| Three-pillar observability | ✅ Prom+Loki+Tempo | ❌ | ❌ | partial | ❌ |
| PSS restricted + default-deny | ✅ | ❌ | ❌ | ❌ | ❌ |
| Single-command bring-up | ✅ `make up` | partial | ✅ | partial | partial |

---

## Makefile targets

```bash
make help     # Show all targets
make up       # Full bring-up: create cluster + install platform + buyerchat
make down     # Tear down kind cluster (clean)
make smoke    # Run smoke tests (requires cluster up)
make lint     # Lint all YAML + Helm charts
```

---

## Roadmap

- [x] v1.0 — full stack on kind, real workload demo, 10-min bring-up
- [ ] v1.1 — ACME ClusterIssuer default, mkcert option, External Secrets Operator
- [ ] v1.2 — Longhorn/OpenEBS for storage demo, Cilium CNI option
- [ ] v1.3 — production migration guide (line-by-line: what changes for EKS/GKE/AKS)

---

## What I'd build differently next time

- **Skip the self-signed CA for local dev.** Browsers hate it, mkcert is faster, the cert-manager learning surface should be ACME from day one. v1.1 makes ACME the default with a flag for self-signed.
- **Don't use kind for the storage demo.** Local PVs work but feel synthetic. v1.2 swaps in Longhorn or OpenEBS so the storage demo behaves more like production.
- **Ship a "what changes for production" diff doc.** People copy Stackup, deploy it to EKS, and find ten subtle differences. v1.3 ships the line-by-line guide.

If you copy this to start a real cluster, expect those three to be your first three follow-up tasks.

---

## Limits

- No real LoadBalancer service type (kind doesn't ship one). We use hostPort. For real LB, deploy to a cloud cluster.
- Storage is local-path PVs by default. Re-creating the cluster wipes them. Add Longhorn or OpenEBS if you need persistence across teardowns.
- Single-tenant workload namespace. Multi-tenant needs additional NetworkPolicy and RBAC work (PRs welcome).
- The buyerchat workload runs degraded (no DB). That's intentional — the cluster is the demo, not the app.

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).