[![Test Status](https://github.com/ykstorm/devops-showcase/actions/workflows/ci.yml/badge.svg)](https://github.com/ykstorm/devops-showcase/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

# devops-showcase

**GitOps-native Kubernetes platform on your local machine.**  
kind cluster + ArgoCD app-of-apps + Argo Rollouts (canary deploys + auto-rollback) + Prometheus + Loki + Tempo + Grafana. `make up` brings up the full stack in under 10 minutes. $0 infra cost.

Built as the platform-engineering counterpart to Homesty.ai's buyerchat — demonstrates the infrastructure that production software runs on.

---

## What it includes

| Layer | Component | What it does |
|-------|-----------|-------------|
| **GitOps** | ArgoCD (app-of-apps) | 8 child apps managed from one root app — sync-policy automated + prune + self-heal |
| **Progressive delivery** | Argo Rollouts | Canary deploys: 25% → 50% → 75% → 100%, auto-rollback on error spike |
| **Ingress** | ingress-nginx | TLS termination, proxy to buyerchat:3000 |
| **TLS** | cert-manager | Self-signed CA ClusterIssuer (swap to ACME for production) |
| **Secrets** | Sealed Secrets | Encrypted secrets committed to git, controller decrypts in-cluster |
| **Metrics** | Prometheus + kube-prometheus-stack | /api/metrics scrape, 30s interval, Grafana auto-import |
| **Logs** | Loki + Promtail | Pod stdout → Loki → Grafana Explore |
| **Traces** | Tempo (monolithic) | OTLP traces from buyerchat if emitted natively |
| **Security** | NetworkPolicy (default-deny) + PSS restricted | Zero trust on workload namespaces |

---

## Quick start

```bash
# Prerequisites: docker, kind, helm, kubectl, git

# Full bring-up
make up

# Full teardown
make down

# After bring-up — verify
curl https://buyerchat.local.devops-showcase.dev/api/healthcheck
# → HTTP 503 {"status":"degraded","reason":"db_unreachable"} (expected — no real DB)
```

### Host entries required

Add to `/etc/hosts`:
```
127.0.0.1 buyerchat.local.devops-showcase.dev
127.0.0.1 grafana.local.devops-showcase.dev
127.0.0.1 argocd.local.devops-showcase.dev
127.0.0.1 prometheus.local.devops-showcase.dev
```

---

## Architecture

```
browser
   │
   ▼ HTTPS (cert-manager self-signed CA)
ingress-nginx (hostPort 80/443)
   │
   ▼ TLS termination → proxy_pass buyerchat.app:3000
buyerchat Service (ClusterIP :3000)
   │
   ▼  (canary 25%→50%→75%→100%, Argo Rollouts)
buyerchat Pods (2 replicas, restricted PSS)
   ├──→ Prometheus /api/metrics (ServiceMonitor, 30s)
   ├──→ Promtail → Loki
   └──→ OTLP → Tempo :4317

─────────────────────────────────────────────

git push origin main
        │
        ▼
ArgoCD root Application (app-of-apps, automated sync)
        │
        ▼
8 child Applications (sync waves: 0=foundation, 1=observability, 2=workload)
  ingress-nginx | cert-manager | sealed-secrets | argo-rollouts
  prometheus | loki | tempo
  buyerchat (Argo Rollouts Rollout CRD)
        │
        ▼
Argo Rollouts kicks off canary on image tag or values diff
```

---

## Key decisions documented

- **Self-signed CA vs ACME**: Local cluster can't reach Let's Encrypt — self-signed works identically, swap is one line
- **Sealed Secrets vs Vault/ESO**: Sufficient for showcase; controller key is per-cluster, documented limitation
- **kind vs k3d vs minikube vs cloud**: kind is most portable, $0 cost
- **Tempo monolithic vs distributed**: Single binary, sufficient for showcase

Full tradeoffs in [`docs/tradeoffs.md`](./docs/tradeoffs.md).

---

## License

Apache 2.0 — see [LICENSE](./LICENSE).