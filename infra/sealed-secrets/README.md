# sealed-secrets (P3 Day 3)

Bitnami's sealed-secrets controller. Lets us commit encrypted Secret
material to git and have the in-cluster controller decrypt it into a
real `Secret` at apply time.

## Install

```sh
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update sealed-secrets

helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --wait --timeout 3m
```

The controller release name `sealed-secrets` and namespace
`kube-system` are baked into the `kubeseal` invocations in this repo
(see `helm/buyerchat/templates/sealed-secret.yaml` provenance) — if
you change either, every `kubeseal` call needs the matching
`--controller-name` / `--controller-namespace` flags.

## Verify

```sh
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
# expect: 1/1 Running

kubeseal --version
# expect: 0.27.2 or compatible
```

## Encrypting a Secret (round-trip example)

```sh
# 1. Create the plaintext Secret YAML (do NOT apply it).
kubectl create secret generic example \
  --from-literal=KEY=value \
  --dry-run=client -o yaml \
  > /tmp/example.yaml

# 2. Encrypt with kubeseal — the resulting YAML is safe to commit.
cat /tmp/example.yaml \
  | kubeseal --format yaml \
      --controller-namespace kube-system \
      --controller-name sealed-secrets \
  > example-sealed.yaml

# 3. Apply the SealedSecret. The in-cluster controller materializes a
#    matching Secret automatically; the SealedSecret CR sticks around.
kubectl apply -f example-sealed.yaml
kubectl get secret example -o yaml
```

## Showcase-accepted limit: ephemeral controller key

The sealed-secrets controller generates a fresh sealing key on first
install and persists it as a `Secret` in `kube-system`. **That key is
local to this kind cluster.** If `down.ps1` runs (which deletes the
cluster), the next `up.ps1` brings up a NEW controller with a NEW
key, and any SealedSecret YAML committed against the old key will no
longer decrypt — the controller will log
`Decryption error: no key could decrypt secret`.

For this showcase that's intentional and accepted:

- an earlier iteration's SealedSecret only protects stub values (`demo-not-real`,
  `example.invalid` — see `manifests/buyerchat/10-secret-stub.yaml`).
  Re-sealing them after a cluster recreate is a 30-second `kubeseal`
  re-run, not a recovery operation.
- Production deployments would back up the controller's sealing key
  via:
  ```sh
  kubectl get secret -n kube-system \
    -l sealedsecrets.bitnami.com/sealed-secrets-key \
    -o yaml \
    > .secrets/sealed-secrets-key.yaml   # NEVER committed
  ```
  …and restore it before the new controller comes up:
  ```sh
  kubectl apply -f .secrets/sealed-secrets-key.yaml
  kubectl rollout restart deploy/sealed-secrets -n kube-system
  ```
- cleanup ticket logs this; it's not a task because the
  showcase has no real secrets to lose.

## cleanup

When ArgoCD takes over (Day 6+), this controller install becomes an
Argo `Application` pointing at a kustomization that wraps the chart.
The `helm install` command above gets retired.
