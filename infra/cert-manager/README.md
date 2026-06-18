# cert-manager (P3 Day 3)

cert-manager + a single self-signed `ClusterIssuer` named `selfsigned`.
TLS for the showcase comes from this Issuer; ingress-nginx serves the
issued cert on `https://buyerchat.localtest.me/`.

## Install

```sh
helm repo add jetstack https://charts.jetstack.io
helm repo update jetstack

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true \
  --wait --timeout 5m

kubectl apply -f infra/cert-manager/clusterissuer-selfsigned.yaml
```

## Why a single self-signed Issuer (not ACME / Let's Encrypt)

- Let's Encrypt's HTTP-01 challenger needs a public DNS name it can
  reach. `buyerchat.localtest.me` resolves to 127.0.0.1 from
  *anywhere*, so the challenger's connection attempt would loop back
  to its own host, never reaching our cluster.
- DNS-01 would work but requires a paid DNS provider with an API
  token — out of scope for a $0-cost local showcase.
- Self-signed gives us a working TLS handshake; the only cost is
  browsers / curl reject the chain by default. `curl -k` covers the
  smoke-test case.

The single-line ClusterIssuer swap to ACME is captured in the an earlier iteration
`docs/tradeoffs.md` entry.

## How buyerchat consumes it

The chart's Ingress carries:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: selfsigned
spec:
  tls:
    - hosts: [buyerchat.localtest.me]
      secretName: buyerchat-tls
```

cert-manager observes the Ingress, creates a `Certificate` CR for
`buyerchat-tls`, signs it via the `selfsigned` Issuer, and writes the
resulting key + cert into the named Secret. ingress-nginx mounts the
Secret and serves it on the TLS handshake.

## Verify

```sh
kubectl get clusterissuer selfsigned -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# expect: True

kubectl get certificate -n buyerchat
# expect (after the chart installs): buyerchat-tls  True
```
