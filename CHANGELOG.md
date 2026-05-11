# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-05-11

### Added
- `.github/workflows/ci.yml` — Helm lint, kubeconform validation, YAML schema checks, no deprecated API detection
- `Makefile` — `make up`, `make down`, `make smoke`, `make lint` targets
- `scripts/smoke-test.sh` — 7-step local pre-commit validation: helm lint, template render, resource presence, deprecated APIs, YAML parse, SealedSecret, ServiceMonitor
- `.gitignore` — excludes node_modules, dist, .env, coverage, *.tmp

### Changed
- README badges added (Test Status, License)
- `make lint` validates all YAML files parse correctly
- `make smoke` runs full validation before cluster apply

## [1.0.0] - 2026-05-06

### Added
- Initial release: kind cluster + Calico CNI + ingress-nginx + cert-manager + sealed-secrets + Argo Rollouts + kube-prometheus-stack + Loki + Tempo + ArgoCD app-of-apps + buyerchat workload Helm chart
- `make up` brings up the full stack in under 10 minutes, $0 infra cost
- `README.md` with architecture diagram, key decisions documented in `docs/tradeoffs.md`