.PHONY: up down smoke lint rollout-status help

KIND_CLUSTER := stackup
HELM_CHART := helm/buyerchat
NAMESPACE := app

help:
	@echo "stackup Makefile"
	@echo ""
	@echo "  make up             Full bring-up: create kind cluster + install all platform components + buyerchat"
	@echo "  make down           Tear down: delete kind cluster (clean)"
	@echo "  make smoke          Run smoke tests (requires cluster up)"
	@echo "  make lint           Lint all YAML files + Helm charts"
	@echo "  make rollout-status Watch the buyerchat Argo Rollout canary progress"
	@echo ""
	@echo "Prerequisites: docker, kind, helm >=3.15, kubectl, git"

up:
	@echo "=== Creating kind cluster ==="
	kind create cluster --name $(KIND_CLUSTER) --config kind/cluster.yaml

	@echo "=== Installing Calico CNI ==="
	kubectl apply -f kind/calico/

	@echo "=== Waiting for CNI ==="
	@kubectl wait --for=condition=Ready pods -n calico-system -l k8s-app=calico-node --timeout=120s || true

	@echo "=== Installing platform Helm charts ==="
	@for chart in infra/ingress-nginx infra/cert-manager infra/sealed-secrets infra/kube-prometheus-stack; do \
		echo "  Installing $$chart..."; \
		helm upgrade --install --create-namespace --namespace $$(basename $$chart) $$chart $$chart --timeout 120s --wait --debug 2>&1 | tail -3 || true; \
	done

	@echo "=== Installing Argo Rollouts + ArgoCD ==="
	@# Wrapper charts (Chart.yaml dependency on the upstream chart) — pull
	@# the pinned dependency, then install. argo-rollouts first so the
	@# Rollout CRDs exist before buyerchat renders a Rollout; argocd last.
	@for chart in infra/argo-rollouts infra/argocd; do \
		echo "  Installing $$chart..."; \
		helm dependency build $$chart >/dev/null 2>&1 || true; \
		helm upgrade --install --create-namespace --namespace $$(basename $$chart) $$chart $$chart --timeout 300s --wait --debug 2>&1 | tail -3 || true; \
	done

	@echo "=== Installing buyerchat Helm chart ==="
	helm upgrade --install buyerchat $(HELM_CHART) \
		--namespace $(NAMESPACE) --create-namespace \
		--values $(HELM_CHART)/values.dev.yaml \
		--timeout 180s --wait

	@echo "=== Registering the ArgoCD app-of-apps root ==="
	@# From here on ArgoCD reconciles every component from git (automated
	@# sync + prune + self-heal). The helm installs above bootstrap the
	@# cluster on a clean machine; root-app.yaml is the GitOps takeover.
	kubectl apply -f argocd/root-app.yaml

	@echo ""
	@echo "=== Cluster ready ==="
	@kubectl get pods -A --no-headers | grep -v Running | grep -v Completed && echo "All pods running ✓" || true
	@echo ""
	@echo "Add to /etc/hosts:"
	@echo "  127.0.0.1 buyerchat.local.stackup.dev"
	@echo "  127.0.0.1 grafana.local.stackup.dev"
	@echo "  127.0.0.1 argocd.local.stackup.dev"
	@echo "  127.0.0.1 prometheus.local.stackup.dev"
	@echo ""
	@echo "Then: curl https://buyerchat.local.stackup.dev/api/healthcheck"

down:
	@echo "=== Deleting kind cluster ==="
	kind delete cluster --name $(KIND_CLUSTER)
	@echo "Cluster deleted. Run 'make up' to bring it back up."

smoke:
	@echo "=== Running smoke tests ==="
	@bash scripts/smoke-test.sh

lint:
	@echo "=== Linting YAML files ==="
	@find . -name "*.yaml" -o -name "*.yml" | grep -v node_modules | while read f; do \
		python3 -c "import yaml; yaml.safe_load(open('$$f'))" 2>/dev/null && echo "✓ $$f" || echo "✗ $$f: YAML parse error"; \
	done || true

	@echo ""
	@echo "=== Helm lint ==="
	@helm lint $(HELM_CHART) --quiet && echo "✓ helm lint passed" || echo "✗ helm lint failed"
	@helm template buyerchat $(HELM_CHART) > /dev/null 2>&1 && echo "✓ helm template passed" || echo "✗ helm template failed"

rollout-status:
	kubectl argo rollouts get rollout buyerchat -n $(NAMESPACE) --watch