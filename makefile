# P1 Dev Guard Makefile
# Big Bang compliance automation for developers

# Load environment variables
include make/.env
export

# Default target
.PHONY: help
help: ## Show this help message
	@echo 'P1 Dev Guard - Big Bang Compliance Toolkit'
	@echo ''
	@echo 'Usage:'
	@echo '  make <target>'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: bootstrap
bootstrap: ## Install git hooks and setup development environment
	@echo "🚀 Bootstrapping P1 Dev Guard development environment..."

	# Install git hooks
	@if [ -d .git ]; then \
		git config core.hooksPath .git-hooks; \
		echo "✅ Git hooks configured"; \
	else \
		echo "⚠️  Not a git repository - hooks not configured"; \
	fi

	# Create artifacts directories
	@mkdir -p artifacts/{reports,sbom,attestations}
	@echo "✅ Artifact directories created"

	# Create cosign key directory if it doesn't exist
	@mkdir -p ~/.p1devguard/keys
	@echo "✅ Cosign key directory ready"

	# Verify tools are available
	@echo "🔍 Verifying required tools..."
	@command -v docker >/dev/null 2>&1 || echo "❌ Docker not found - install Docker"
	@command -v helm >/dev/null 2>&1 || echo "❌ Helm not found - run in devcontainer"
	@command -v git >/dev/null 2>&1 || echo "❌ Git not found"

	@echo "✅ P1 Dev Guard bootstrap complete!"
	@echo "💡 Run 'make verify' to validate your application"

.PHONY: verify
verify: ## Run comprehensive Big Bang compliance verification
	@echo "🔍 Running Big Bang compliance verification..."
	@bash make/bb-verify.sh

.PHONY: lint
lint: ## Run basic linting and syntax checks
	@echo "📝 Running linting checks..."

	# YAML linting
	@if command -v yamllint >/dev/null 2>&1; then \
		find . -name "*.yaml" -o -name "*.yml" | grep -v node_modules | xargs yamllint --config-data '{extends: default, rules: {line-length: {max: 120}, indentation: {spaces: 2}}}' || true; \
	else \
		echo "⚠️  yamllint not found - install with 'pip install yamllint'"; \
	fi

	# Helm chart linting
	@if [ -d "$(HELM_CHART_PATH)" ]; then \
		helm lint $(HELM_CHART_PATH) || exit 1; \
		echo "✅ Helm chart linting passed"; \
	fi

.PHONY: chart
chart: ## Package and validate Helm chart
	@echo "📊 Processing Helm chart..."

	# Validate chart structure
	@if [ ! -d "$(HELM_CHART_PATH)" ]; then \
		echo "❌ Helm chart not found at $(HELM_CHART_PATH)"; \
		exit 1; \
	fi

	# Lint chart
	@helm lint $(HELM_CHART_PATH)

	# Template chart
	@helm template $(APP_NAME) $(HELM_CHART_PATH) --validate

	# Package chart
	@mkdir -p artifacts/charts
	@helm package $(HELM_CHART_PATH) --destination artifacts/charts
	@echo "✅ Helm chart packaged successfully"

.PHONY: sbom
sbom: ## Generate Software Bill of Materials
	@echo "📄 Generating SBOM..."
	@mkdir -p artifacts/sbom

	@if command -v syft >/dev/null 2>&1; then \
		COMMIT_SHA=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown"); \
		syft dir:. -o spdx-json > artifacts/sbom/$${COMMIT_SHA}.spdx.json; \
		echo "✅ SBOM generated: artifacts/sbom/$${COMMIT_SHA}.spdx.json"; \
	else \
		echo "❌ syft not found - run in devcontainer or install syft"; \
		exit 1; \
	fi

.PHONY: scan
scan: ## Run security vulnerability scanning
	@echo "🔒 Running security scans..."

	# Dockerfile scanning
	@if [ -f "build/Dockerfile" ] && command -v hadolint >/dev/null 2>&1; then \
		hadolint --ignore $(HADOLINT_IGNORE) build/Dockerfile; \
		echo "✅ Dockerfile scan passed"; \
	else \
		echo "⚠️  Skipping Dockerfile scan - hadolint not found or no Dockerfile"; \
	fi

	# Filesystem vulnerability scanning
	@if command -v trivy >/dev/null 2>&1; then \
		trivy fs --severity $(TRIVY_SEVERITY) --exit-code 1 .; \
		echo "✅ Vulnerability scan passed"; \
	else \
		echo "❌ trivy not found - run in devcontainer or install trivy"; \
		exit 1; \
	fi

.PHONY: dev-up
dev-up: ## Start local development environment with k3d
	@echo "🚀 Starting local development environment..."

	@if ! command -v k3d >/dev/null 2>&1; then \
		echo "❌ k3d not found - run in devcontainer or install k3d"; \
		exit 1; \
	fi

	# Check if cluster already exists
	@if k3d cluster list | grep -q $(K3D_CLUSTER_NAME); then \
		echo "✅ Cluster $(K3D_CLUSTER_NAME) already exists"; \
	else \
		echo "Creating k3d cluster: $(K3D_CLUSTER_NAME)"; \
		k3d cluster create $(K3D_CLUSTER_NAME) \
			--port "8080:80@loadbalancer" \
			--port "8443:443@loadbalancer" \
			--k3s-arg "--disable=traefik@server:0"; \
	fi

	# Create namespace
	@kubectl create namespace $(DEV_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

	@echo "✅ Development environment ready!"
	@echo "💡 Use 'kubectl config use-context k3d-$(K3D_CLUSTER_NAME)' to switch context"

.PHONY: dev-down
dev-down: ## Stop local development environment
	@echo "🛑 Stopping local development environment..."

	@if command -v k3d >/dev/null 2>&1; then \
		if k3d cluster list | grep -q $(K3D_CLUSTER_NAME); then \
			k3d cluster delete $(K3D_CLUSTER_NAME); \
			echo "✅ Cluster $(K3D_CLUSTER_NAME) deleted"; \
		else \
			echo "⚠️  Cluster $(K3D_CLUSTER_NAME) not found"; \
		fi \
	else \
		echo "⚠️  k3d not found - cluster may still be running"; \
	fi

.PHONY: deploy-local
deploy-local: dev-up chart ## Deploy application to local k3d cluster
	@echo "🚀 Deploying to local development cluster..."

	# Install/upgrade chart
	@helm upgrade --install $(APP_NAME) $(HELM_CHART_PATH) \
		--namespace $(DEV_NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 10m

	@echo "✅ Application deployed successfully!"
	@echo "🌐 Access your application at: http://localhost:8080"

.PHONY: clean
clean: ## Clean up artifacts and temporary files
	@echo "🧹 Cleaning up artifacts..."
	@rm -rf artifacts/
	@rm -rf manifests_temp/
	@echo "✅ Cleanup complete"

.PHONY: build-toolchain
build-toolchain: ## Build the P1 Dev Guard toolchain container
	@echo "🔨 Building P1 Dev Guard toolchain container..."
	@docker build -t $(TOOL_IMAGE) build/toolchain/
	@echo "✅ Toolchain container built: $(TOOL_IMAGE)"

.PHONY: push-toolchain
push-toolchain: build-toolchain ## Build and push toolchain container
	@echo "📤 Pushing toolchain container..."
	@docker push $(TOOL_IMAGE)
	@echo "✅ Toolchain container pushed: $(TOOL_IMAGE)"

.PHONY: test-policies
test-policies: ## Test OPA policies with sample manifests
	@echo "🧪 Testing OPA policies..."

	@if [ ! -d "test/" ]; then \
		echo "❌ Test directory not found"; \
		exit 1; \
	fi

	@echo "Testing passing samples..."
	@if command -v conftest >/dev/null 2>&1; then \
		conftest test test/passing-sample/ --policy $(CONFTEST_POLICY_PATH); \
		echo "✅ Passing samples validated"; \
	else \
		echo "❌ conftest not found"; \
		exit 1; \
	fi

	@echo "Testing failing samples (should fail)..."
	@if conftest test test/failing-sample/ --policy $(CONFTEST_POLICY_PATH) 2>/dev/null; then \
		echo "❌ Failing samples should have failed!"; \
		exit 1; \
	else \
		echo "✅ Failing samples correctly rejected"; \
	fi

.PHONY: docs
docs: ## Generate documentation
	@echo "📚 Generating documentation..."
	@echo "Architecture documentation: docs/ARCHITECTURE.md"
	@echo "API documentation: helm/$(APP_NAME)/values.schema.json"
	@echo "Policy documentation: policies/*.rego"

.PHONY: status
status: ## Show current project status
	@echo "📊 P1 Dev Guard Status"
	@echo "======================"
	@echo "Application: $(APP_NAME)"
	@echo "Version: $(APP_VERSION)"
	@echo "Chart Path: $(HELM_CHART_PATH)"
	@echo "Tool Image: $(TOOL_IMAGE)"
	@echo ""
	@echo "Git Status:"
	@git status --short || echo "Not a git repository"
	@echo ""
	@echo "Recent Artifacts:"
	@find artifacts/ -type f -name "*.json" -o -name "*.jsonl" -o -name "*.spdx.json" 2>/dev/null | head -5 || echo "No artifacts found"

# Utility targets for development
.PHONY: helm-template
helm-template: ## Template Helm chart for debugging
	@helm template $(APP_NAME) $(HELM_CHART_PATH) --values $(HELM_CHART_PATH)/values.yaml

.PHONY: kubectl-apply
kubectl-apply: helm-template ## Apply templated manifests to cluster
	@helm template $(APP_NAME) $(HELM_CHART_PATH) | kubectl apply -f -

.PHONY: kubectl-delete
kubectl-delete: ## Delete resources from cluster
	@helm template $(APP_NAME) $(HELM_CHART_PATH) | kubectl delete -f - --ignore-not-found=true

# Container-specific targets
.PHONY: build-container
build-container: ## Build the P1 Dev Guard container
	@echo "🔨 Building P1 Dev Guard container..."
	@docker build -t p1guard:latest -f build/toolchain/Dockerfile .
	@echo "✅ Container built: p1guard:latest"

.PHONY: test-container
test-container: build-container ## Build and test the container
	@echo "🧪 Testing P1 Dev Guard container..."
	@bash test-container.sh

.PHONY: run-container
run-container: ## Run the container against current project
	@echo "🚀 Running P1 Dev Guard container..."
	@docker run --rm \
		-v "$(shell pwd):/workspace" \
		-v "${HOME}/.p1devguard/keys:/keys:ro" \
		p1guard:latest

.PHONY: container-help
container-help: ## Show container usage help
	@docker run --rm p1guard:latest --help