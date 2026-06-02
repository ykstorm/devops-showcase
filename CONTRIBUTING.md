# Contributing to Stackup

Thank you for your interest in contributing!

## How to contribute

1. **Fork the repo** and create a branch from `main`.
2. **Make your changes** — keep them focused and small.
3. **Run `make lint`** before opening a PR to catch YAML/Helm issues early.
4. **Open a PR** — describe what changed and why.
5. **CI must pass** — `make lint` + helm template validation.

## What to contribute

- Bug fixes with clear reproduction steps
- Docs corrections (README, architecture, tradeoffs)
- Additional smoke tests in `scripts/smoke-test.sh`
- Improvements to Helm chart templates

## What not to contribute yet

- Changes to core platform components (ingress-nginx, cert-manager, etc.) unless a bug is confirmed
- Multi-cluster or multi-tenant features — those are v1.x roadmap items
- Changes to the buyerchat workload itself — it is intentionally degraded

## Commit messages

Use conventional commits:

```
feat: add Loki dashboards
fix: correct ingress-nginx hostPort mapping
docs: update quickstart timing
```

## Questions

Open an issue for discussion before opening a large PR — saves everyone time.