# Changelog

All notable changes to this project will be documented in this file.

## [1.0.1] - 2026-05-11

### Added
- `.github/workflows/ci.yml` — Helm lint, kubeconform validation, YAML schema checks
- `Makefile` — `make up`, `make down`, `make smoke`, `make lint` targets
- `scripts/smoke-test.sh` — 7-step validation: helm lint, template, resource presence, no deprecated APIs, YAML parse, SealedSecret, ServiceMonitor
- `.gitignore` — node_modules, dist, .env, coverage, *.tmp

### Changed
- README badges added (Test Status, License)
- Smoke test script added for local pre-commit validation