# Claim audit

Every public claim about stackup, mapped to the code that backs it. Verified
statically (helm lint / helm template / unit tests); the live `make up` run is
a separate gated step (see the PR note).

| Claim | Backed by | Verified |
|---|---|---|
| Self-contained `/metrics` canary workload (no private app) | `apps/demo/server.js` — `prom-client` `Counter` `http_requests_total{service,code,method,path}`, incremented on `res.on('finish')`, exposed at `GET /metrics` | `node --check` + `apps/demo/test/metrics.test.js` (2/2 pass) |
| Image loads into kind without a registry | `apps/demo/Dockerfile` + bootstrap `kind load docker-image` | static |
| `make up` bootstraps in dependency order, waiting between steps | `scripts/bootstrap.sh` — kind create → tigera-operator (`kubectl wait` Available) → Calico Installation → nodes Ready → namespaces → sealed-secrets controller → SealedSecrets → ArgoCD → app-of-apps → Applications Synced | static (live verify pending) |
| Workload + its SealedSecret live in one namespace | unified namespace across `helm/.../sealed-secret.yaml` + `manifests/app/` + the chart | static |
| Canary analysis is a REAL HTTP success-rate, not a liveness check | `helm/demo/templates/analysis-template.yaml` — `sum(rate(http_requests_total{code=~"2.."}[2m])) / sum(rate(http_requests_total[2m]))`, `successCondition result[0] >= 0.95`, Prometheus at `http://prometheus-operated.monitoring.svc:9090` | `helm template -f values.dev.yaml` renders the Rollout + AnalysisTemplate with the real query |
| kube-prometheus-stack scrapes the workload | `helm/demo/templates/servicemonitor.yaml` | `helm template` renders the ServiceMonitor |
| Deployment vs canary Rollout are mutually exclusive | `helm/demo` renders a Deployment by default, a Rollout + AnalysisTemplate under `values.dev.yaml` | `helm template` per values file |
| ~12–15 min on a fresh cluster, single-node kind | `kind/cluster.yaml` (single control-plane); README states measured-pending timing | static |

## Pending live verification

`make up` has not yet been run end-to-end on a kind cluster in this pass. A
follow-up will attach the live `kubectl get pods -A` output and a canary
rollout screenshot, and correct any ingress hostnames to match what actually
resolves on the cluster.
