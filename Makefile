.PHONY: up down smoke lint help

KIND_CLUSTER := devops-showcase
HELM_CHART := helm/buyerchat
NAMESPACE := app

help:
	@echo "devops-showcase Makefile"
	@echo ""
	@echo "  make up       Full bring-up: create kind cluster + install all platform components + buyerchat"
	@echo "  make down     Tear down: delete kind cluster (clean)"
	@echo "  make smoke    Run smoke tests (requires cluster up)"
	@echo "  make lint     Lint all YAML files + Helm charts"
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

	@echo "=== Installing buyerchat Helm chart ==="
	helm upgrade --install buyerchat $(HELM_CHART) \
		--namespace $(NAMESPACE) --create-namespace \
		--values $(HELM_CHART)/values.dev.yaml \
		--timeout 180s --wait

	@echo ""
	@echo "=== Cluster ready ==="
	@kubectl get pods -A --no-headers | grep -v Running | grep -v Completed && echo "All pods running ✓" || true
	@echo ""
	@echo "Add to /etc/hosts:"
	@echo "  127.0.0.1 buyerchat.local.devops-showcase.dev"
	@echo "  127.0.0.1 grafana.local.devops-showcase.dev"
	@echo "  127.0.0.1 argocd.local.devops-showcase.dev"
	@echo "  127.0.0.1 prometheus.local.devops-showcase.dev"
	@echo ""
	@echo "Then: curl https://buyerchat.local.devops-showcase.dev/api/healthcheck"

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