# argocd (P3 Day 6)

Installs ArgoCD (namespace `argocd`) — the GitOps control plane. Once up,
`kubectl apply -f argocd/root-app.yaml` registers the app-of-apps root,
which reconciles one child `Application` per platform component (see
`argocd/apps/`) against this repo with automated sync, prune, and
self-heal.

This directory is a self-contained wrapper chart: `Chart.yaml` pins the
upstream `argo/argo-cd` chart (`9.5.21`) as a dependency, so `helm lint`
runs in CI and the bring-up renders without an out-of-band `helm repo add`.

## Install / upgrade

```sh
helm dependency build infra/argocd
helm upgrade --install argocd infra/argocd \
  --namespace argocd --create-namespace \
  --wait --timeout 5m

kubectl apply -f argocd/root-app.yaml
```

## Access

The server is reachable at https://argocd.local.stackup.dev (TLS
terminated by cert-manager's selfsigned ClusterIssuer; `curl -k` for the
self-signed chain). The initial admin password:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

## Why insecure server behind the ingress

The ingress terminates TLS. Running the ArgoCD server in insecure (plain
HTTP) mode behind it (`configs.params."server.insecure": true`) avoids a
second TLS hop where the server would serve its own cert under the
ingress cert. This is the standard ingress-fronted ArgoCD posture.
