# kube-prometheus-stack (P3 Day 4)

The Prometheus + Grafana + kube-state-metrics + node-exporter +
prometheus-operator stack for the showcase. One Helm release, one
namespace (`monitoring`).

## Install

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community

helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f infra/kube-prometheus-stack/values.yaml \
  --wait --timeout 10m
```

Pinned to the chart version on the Helm repo at install time
(`84.5.0` / app `v0.90.1` at the time of writing). The release name
**`kps`** is load-bearing: ServiceMonitors authored elsewhere
(notably `helm/buyerchat`'s ServiceMonitor in Day-4 Phase C) carry
`labels.release: kps` so the operator picks them up.

## Access

| URL | Service |
|---|---|
| https://grafana.localtest.me | Grafana — login `admin` / `prom-operator` |
| `kubectl port-forward -n monitoring svc/kps-kube-prometheus-stack-prometheus 9090:9090` | Prometheus UI / `/targets` |

### Why `prom-operator` is acceptable here

It's the chart's own well-known default. This is a showcase cluster
with no real data; the trade-off is "anyone with kubectl can read it
anyway, so signaling provenance is more useful than rotating it."
Production would set `grafana.adminPassword: ""` and inject via
`grafana.admin.existingSecret` pointing at a SealedSecret-decrypted
Secret.

## Critical override: `serviceMonitorSelectorNilUsesHelmValues=false`

By default the operator only adopts ServiceMonitor / PodMonitor /
PrometheusRule / Probe objects that carry the chart's release label
(`release=kps`). When set to `false` (in `values.yaml`) the selector
becomes "any matching object cluster-wide" — necessary for the
buyerchat chart's ServiceMonitor (Phase C) to be picked up without
having to copy the magic label.

The four `*SelectorNilUsesHelmValues: false` toggles in `values.yaml`
all share this rationale.

## Storage trade-off (showcase: emptyDir)

Both Prometheus and Grafana use **emptyDir** volumes. Data lives in
the pod's tmpfs; on `down.ps1 + up.ps1` (or any pod restart) every
metric and every imported dashboard is gone. Re-import takes ~5
seconds because dashboards are sourced from in-tree ConfigMaps
labeled `grafana_dashboard: "1"`, not from Grafana's SQLite store.

Production would attach a PVC (`prometheus.prometheusSpec.storageSpec`
+ `grafana.persistence.enabled=true`) backed by a real
StorageClass. For a $0-cost local kind cluster the laptop's host-path
PV provisioner exists but adds noise without value; losing 24h of
demo metrics on a recycle is fine.

## Default scrape config

`scrapeInterval: 30s` for everything that doesn't override on the
ServiceMonitor itself. Cheap on a kind cluster, plenty of resolution
for a showcase.

## Kind-specific quirk: 4 control-plane targets show `down`

After install, `/api/v1/targets` lists 12 up / 4 down:

```
kube-controller-manager   down
kube-etcd                 down
kube-proxy                down
kube-scheduler            down
```

These are kind-specific. The chart's bundled ServiceMonitors expect
control-plane components on standard ports (`10257`, `2381`,
`10249`, `10259`); kind runs them as static pods bound to localhost
only, and `--bind-address` is hard to flip after `kind create`. The
12 healthy targets cover the showcase demo surface
(kube-state-metrics, node-exporter, Grafana, the operator,
Prometheus self-scrape, kubelet, coredns, apiserver). Not fixing on
this sprint — would require a kind cluster patch + redeploy that
buys nothing for the demo.

The chart-bundled `kubeControllerManager.enabled` / `kubeEtcd` /
`kubeProxy` / `kubeScheduler` toggles can be set to `false` to drop
these targets from the UI; on this showcase we keep them visible to
make the kind quirk obvious to a recruiter reading the dashboards.

## Verify

```sh
# All monitoring pods Running
kubectl get pods -n monitoring

# Grafana ingress reachable via TLS (self-signed)
curl -k -i https://grafana.localtest.me     # expect 302 to /login

# cert-manager issued the TLS Secret
kubectl get certificate -n monitoring grafana-tls   # READY=True

# Prometheus scrape targets
kubectl port-forward -n monitoring svc/kps-kube-prometheus-stack-prometheus 9090:9090
# in another shell:
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health}'
```

## Day-7 cleanup

When ArgoCD takes over (Day 6+), this stack becomes an ArgoCD
`Application` pointing at this same `infra/kube-prometheus-stack/`
directory (via a chart-of-charts shim). The `helm install` command
above gets retired in favor of `argocd app sync`.
