# ingress-nginx (P3 Day 3)

The single ingress controller for the showcase cluster. Installed via
the upstream Helm chart with a small set of overrides captured in
[`values.yaml`](./values.yaml) so the install posture is reviewable in
git rather than buried in a one-shot `--set` flag.

## Install / upgrade

```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f infra/ingress-nginx/values.yaml \
  --wait --timeout 5m
```

## How it reaches the laptop

```
laptop:443  ──Docker port-publish──▶  kind-node:443  ──hostPort──▶  ingress-nginx-controller pod
                                       (extraPortMappings              (controller.hostPort.enabled=true)
                                        in kind/cluster.yaml)
```

If `https://buyerchat.localtest.me/` does not resolve to the
controller, check both halves of that path:

1. `docker ps --format '{{.Names}}\t{{.Ports}}' | grep stackup`
   must show `0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp`. If missing,
   `kind/cluster.yaml` lost its `extraPortMappings` and the cluster
   needs `down.ps1 + up.ps1` to recreate.
2. `kubectl get pods -n ingress-nginx` must show the controller pod
   `1/1 Running`. If `Pending`, hostPort is taken by another pod —
   typically a stale rollout (see the `Recreate` strategy note in
   `values.yaml`).

## Upgrade strategy

`controller.updateStrategy.type = Recreate` (not `RollingUpdate`).
Single-node clusters can only have one pod bound to hostPort 80/443
at a time; rolling-update would deadlock waiting for the new pod to
become Ready while the old pod still holds the port. Recreate kills
the old pod first, then schedules the new one. Trade: ~5 s of ingress
downtime per upgrade — acceptable on a showcase cluster.

## Mutually-exclusive flags

`--publish-status-address` and `--publish-service` are mutually
exclusive (the controller F-fatals at startup if both are set). The
chart enables `publishService` by default; we disable it in
`values.yaml` so our `--publish-status-address=localhost` override
takes effect (and ingress objects' `.status.loadBalancer.ingress[]`
gets a sensible value instead of being permanently empty).

## Day-7 cleanup ticket

When ArgoCD is wired up on Day 6, this controller becomes an Argo
`Application` pointing at this same `infra/ingress-nginx/` directory
(plus a `Chart.yaml` shim if the chart-of-charts pattern is chosen).
The install command above gets retired in favor of an `argocd app
sync` flow.
