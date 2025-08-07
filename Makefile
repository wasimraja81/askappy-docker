# Multi-Project Makefile for askappy-docker repository
# Supports multiple independent Docker projects

.PHONY: help build test push clean list-projects


# Project configurations (dynamically from projects.yml)
DATE := $(shell date +%Y%m%d)
SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
ASKAPPY_IMAGE := $(shell yq e '.projects."askappy-base".image_name' projects.yml)
ASKAPPY_RAW_TAG := $(shell yq e '.projects."askappy-base".base_tag' projects.yml)
ASKAPPY_TAG := $(ASKAPPY_RAW_TAG)-$(DATE)-$(SHA)
TOSTOOL_IMAGE := $(shell yq e '.projects.tostool.image_name' projects.yml)
TOSTOOL_RAW_TAG := $(shell yq e '.projects.tostool.base_tag' projects.yml)
TOSTOOL_TAG := $(TOSTOOL_RAW_TAG)-$(DATE)-$(SHA)

PLATFORMS := linux/amd64,linux/arm64

# Colors for output
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m

# Default target
help: ## Show this help message
	@echo "$(BLUE)askappy-docker Multi-Project Build System$(NC)"
	@echo "============================================="
	@echo ""
	@echo "Available commands:"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Project-specific commands:"
	@echo "  $(GREEN)build-askappy$(NC)                Build askappy-base image"
	@echo "  $(GREEN)build-askappy-local$(NC)          Build askappy-base locally (no push)"
	@echo "  $(GREEN)build-tostool$(NC)                Build + PUSH tostool (production)"
	@echo "  $(GREEN)build-tostool-local-base$(NC)     Build tostool using LOCAL base (dev)"
	@echo "  $(GREEN)build-tostool-registry-base$(NC)  Build tostool using REGISTRY base (test)"
	@echo "  $(GREEN)test-askappy$(NC)                 Test askappy-base image"
	@echo "  $(GREEN)test-askappy-local$(NC)           Test askappy-base local image"
	@echo "  $(GREEN)test-tostool-local-base$(NC)      Test local-base build"
	@echo "  $(GREEN)push-askappy$(NC)                 Push askappy-base image"
	@echo "  $(GREEN)clean-temp$(NC)                   Clean temporary files"
	@echo "  $(GREEN)tag-release$(NC)                  Tag and build release version"
	@echo ""
	@echo "Examples:"
	@echo "  make build-askappy      # Build askappy-base project"
	@echo "  make test-askappy       # Test askappy-base project"
	@echo "  make build-all          # Build all enabled projects"

# Project listing
list-projects: ## List all available projects
	@echo "$(BLUE)Available Projects:$(NC)"
	@if command -v yq >/dev/null 2>&1; then \
	  for project in askappy-base tostool; do \
		enabled=$$(yq e ".projects.$$project.enabled" projects.yml); \
		if [ "$$enabled" = "true" ]; then \
		  color="$(GREEN)"; status="[enabled]"; \
		else \
		  color="$(YELLOW)"; status="[disabled]"; \
		fi; \
		image_var=$$(echo $$project | tr '-' '_' | tr '[:lower:]' '[:upper:]')_IMAGE; \
		tag_var=$$(echo $$project | tr '-' '_' | tr '[:lower:]' '[:upper:]')_TAG; \
		image=$${!image_var}; tag=$${!tag_var}; \
		printf "  %b%s%b - %s (%s:%s) %s\n" "$$color" "$$project" "$(NC)" "$$project" "$$image" "$$tag" "$$status"; \
	  done; \
	else \
	  echo "  $(YELLOW)yq not found. Showing static project list.$(NC)"; \
	  echo "  $(GREEN)askappy-base$(NC) - Base image with casacore ($(ASKAPPY_IMAGE):$(ASKAPPY_TAG))"; \
	  echo "  $(YELLOW)tostool$(NC)      - TOSTOOL processing tools ($(TOSTOOL_IMAGE):$(TOSTOOL_TAG)) [disabled - Ubuntu 24.04 ready]"; \
	fi

# Generic build targets
build-all: build-askappy ## Build all enabled projects
	@echo "$(GREEN)All enabled projects built!$(NC)"

test-all: test-askappy ## Test all enabled projects
	@echo "$(GREEN)All enabled projects tested!$(NC)"

push-all: push-askappy ## Push all enabled projects
	@echo "$(GREEN)All enabled projects pushed!$(NC)"

# Askappy-base specific targets
build-askappy: ## Build askappy-base Docker image
	@echo "$(BLUE)Building askappy-base...$(NC)"
	cd askappy-base && ./build.sh

build-askappy-local: ## Build askappy-base locally without pushing
	@echo "$(BLUE)Building askappy-base locally...$(NC)"
	docker buildx build --platform linux/amd64 \
		--tag $(ASKAPPY_IMAGE):$(ASKAPPY_TAG)-local \
		--file askappy-base/Dockerfile \
		--load \
		askappy-base/

test-askappy-local: ## Test askappy-base local image
	@echo "$(BLUE)Testing askappy-base (local build)...$(NC)"
	docker run --rm --platform linux/amd64 $(ASKAPPY_IMAGE):$(ASKAPPY_TAG)-local python3 -c "import casacore, numpy, astropy, pandas, matplotlib; print('✅ askappy-base local test passed')"

test-askappy: ## Test askappy-base Docker image
	@echo "$(BLUE)Testing askappy-base...$(NC)"
	docker run --rm --platform linux/amd64 $(ASKAPPY_IMAGE):$(ASKAPPY_TAG) python3 -c "import casacore, numpy, astropy, pandas, matplotlib; print('✅ askappy-base test passed')"

push-askappy: ## Push askappy-base to Docker Hub
	@echo "$(BLUE)Pushing askappy-base...$(NC)"
	docker push $(ASKAPPY_IMAGE):$(ASKAPPY_TAG)
	docker push $(ASKAPPY_IMAGE):latest

# Tostool specific targets (ready for Ubuntu 24.04)
build-tostool: ## Build and PUSH tostool to Docker Hub [PRODUCTION]
	@echo "$(BLUE)Building and pushing tostool Ubuntu 24.04 to registry...$(NC)"
	@echo "$(YELLOW)⚠️  This will PUSH to Docker Hub$(NC)"
	cd tostool && ./build.sh

build-tostool-local-base: ## Build tostool locally (uses LOCAL base image, no push)
	@echo "$(BLUE)Building tostool locally (using LOCAL base image)...$(NC)"
	@echo "$(YELLOW)Note: Requires Git credentials for CSIRO Bitbucket access$(NC)"
	@echo "$(YELLOW)Note: Uses LOCAL askappy-base image - fastest for development$(NC)"
	cd tostool && \
	mkdir -p askap-repos && \
	cd askap-repos && \
	git clone --recurse-submodules ssh://git@bitbucket.csiro.au:7999/askapsdp/askap-dev.git askap-dev && \
	cd askap-dev && git checkout 2.28.0 && cd .. && \
	git clone --recurse-submodules ssh://git@bitbucket.csiro.au:7999/tos/python-askap.git python-askap && \
	git clone --recurse-submodules ssh://git@bitbucket.csiro.au:7999/tos/python-parset python-parset && \
	git clone --recurse-submodules ssh://git@bitbucket.csiro.au:7999/tos/python-askap-interfaces python-askap-interfaces && \
	git clone --recurse-submodules ssh://git@bitbucket.csiro.au:7999/tos/python-iceutils python-iceutils && \
	git clone --recurse-submodules ssh://git@bitbucket.csiro.au:7999/tos/python-askap-cli.git python-askap-cli && \
	cd .. && \
	sed 's|wasimraja81/askappy-ubuntu-24.04:base-mpich-casacore-3.6.1|$(ASKAPPY_IMAGE):$(ASKAPPY_TAG)-local|g' Dockerfile > Dockerfile.local && \
	docker buildx build --platform linux/amd64 \
		--tag $(TOSTOOL_IMAGE):$(TOSTOOL_TAG)-local \
		--file Dockerfile.local \
		--load \
		. && \
	rm -rf askap-repos Dockerfile.local

build-tostool-registry-base: ## Build tostool locally (uses REGISTRY base image, no push)
	@echo "$(BLUE)Building tostool locally (using REGISTRY base image)...$(NC)"
	@echo "$(YELLOW)Note: Requires Git credentials for CSIRO Bitbucket access$(NC)"
	@echo "$(YELLOW)Note: Uses REGISTRY askappy-base image - good for integration testing$(NC)"
	cd tostool && \
	mkdir -p askap-repos && \
	cd askap-repos && \
	git clone --recurse-submodules ssh://git@bitbucket.csiro.au:7999/askapsdp/askap-dev.git askap-dev && \
	cd askap-dev && git checkout 2.28.0 && cd .. && \
	git clone --recurse-submodules ssh://git@bitbucket.csiro.au:7999/tos/python-askap.git python-askap && \
	git clone --recurse-submodules ssh://git@bitbucket.csiro.au:7999/tos/python-parset python-parset && \
	git clone --recurse-submodules ssh://git@bitbucket.csiro.au:7999/tos/python-askap-interfaces python-askap-interfaces && \
	git clone --recurse-submodules ssh://git@bitbucket.csiro.au:7999/tos/python-iceutils python-iceutils && \
	git clone --recurse-submodules ssh://git@bitbucket.csiro.au:7999/tos/python-askap-cli.git python-askap-cli && \
	cd .. && \
	docker buildx build --platform linux/amd64 \
		--tag $(TOSTOOL_IMAGE):$(TOSTOOL_TAG)-registry \
		--file Dockerfile \
		. && \
	rm -rf askap-repos

test-tostool: ## Test tostool Docker image (production registry version)
	@echo "$(BLUE)Testing tostool (production registry version)...$(NC)"
	@echo "$(YELLOW)Testing ASKAP command-line tools...$(NC)"
	docker run --rm --platform linux/amd64 $(TOSTOOL_IMAGE):$(TOSTOOL_TAG) schedblock info -h > /dev/null
	@echo "$(YELLOW)Testing Python environment...$(NC)"
	docker run --rm --platform linux/amd64 $(TOSTOOL_IMAGE):$(TOSTOOL_TAG) python3 -c "import casacore, numpy; print('✅ tostool production test passed')"

test-tostool-local-base: ## Test tostool built with local base image
	@echo "$(BLUE)Testing tostool (built with local base)...$(NC)"
	@echo "$(YELLOW)Testing ASKAP command-line tools...$(NC)"
	docker run --rm --platform linux/amd64 $(TOSTOOL_IMAGE):$(TOSTOOL_TAG)-local schedblock info -h > /dev/null
	@echo "$(YELLOW)Testing Python environment...$(NC)"
	docker run --rm --platform linux/amd64 $(TOSTOOL_IMAGE):$(TOSTOOL_TAG)-local python3 -c "import casacore, numpy; print('✅ tostool local-base test passed')"

test-tostool-registry-base: ## Test tostool built with registry base image
	@echo "$(BLUE)Testing tostool (built with registry base)...$(NC)"
	@echo "$(YELLOW)Testing ASKAP command-line tools...$(NC)"
	docker run --rm --platform linux/amd64 $(TOSTOOL_IMAGE):$(TOSTOOL_TAG)-registry schedblock info -h > /dev/null
	@echo "$(YELLOW)Testing Python environment...$(NC)"
	docker run --rm --platform linux/amd64 $(TOSTOOL_IMAGE):$(TOSTOOL_TAG)-registry python3 -c "import casacore, numpy; print('✅ tostool registry-base test passed')"

push-tostool: ## Push tostool to Docker Hub
	@echo "$(BLUE)Pushing tostool...$(NC)"
	docker push $(TOSTOOL_IMAGE):$(TOSTOOL_TAG)
	docker push $(TOSTOOL_IMAGE):latest

# Development targets
dev-up: ## Start development environment
	@echo "$(BLUE)Starting development environment...$(NC)"
	docker-compose up -d

dev-down: ## Stop development environment
	@echo "$(BLUE)Stopping development environment...$(NC)"
	docker-compose down

dev-logs: ## Show development environment logs
	docker-compose logs -f

# Maintenance targets
clean: ## Clean up Docker resources
	@echo "$(BLUE)Cleaning up Docker resources...$(NC)"
	docker image prune -f
	docker buildx prune -f
	docker system prune -f

clean-temp: ## Clean up temporary build files
	@echo "$(BLUE)Cleaning up temporary files...$(NC)"
	find . -name "Dockerfile.local" -delete 2>/dev/null || true
	find . -name "askap-repos" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyc" -delete 2>/dev/null || true
	find . -name ".DS_Store" -delete 2>/dev/null || true
	@echo "$(GREEN)Temporary files cleaned!$(NC)"

clean-project: ## Clean images for specific project
	@read -p "Enter project name (askappy-base/tostool): " project; \
	case $$project in \
		askappy-base) \
			docker rmi $(ASKAPPY_IMAGE):$(ASKAPPY_TAG) 2>/dev/null || true; \
			docker rmi $(ASKAPPY_IMAGE):latest 2>/dev/null || true; \
			echo "$(GREEN)Cleaned askappy-base images$(NC)"; \
			;; \
		tostool) \
			docker rmi $(TOSTOOL_IMAGE):$(TOSTOOL_TAG) 2>/dev/null || true; \
			docker rmi $(TOSTOOL_IMAGE):latest 2>/dev/null || true; \
			echo "$(GREEN)Cleaned tostool images$(NC)"; \
			;; \
		*) \
			echo "$(RED)Unknown project: $$project$(NC)"; \
			;; \
	esac

# Quality assurance targets
lint: ## Lint all Dockerfiles
	@echo "$(BLUE)Linting Dockerfiles...$(NC)"
	docker run --rm -i hadolint/hadolint < askappy-base/Dockerfile || true
	# Add tostool when enabled
	# docker run --rm -i hadolint/hadolint < tostool/Dockerfile-tostool-ubuntu-22.04-with-mpich-casacore-3.6.1.txt || true

security-scan-askappy: ## Run security scan on askappy-base
	@echo "$(BLUE)Running security scan on askappy-base...$(NC)"
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		aquasec/trivy image $(ASKAPPY_IMAGE):$(ASKAPPY_TAG)

# Information targets
info: ## Show build information
	@echo "$(BLUE)Multi-Project Build Information:$(NC)"
	@echo "============================================="
	@echo ""
	@echo "📦 Project Dependencies:"
	@echo "  askappy-base: $(ASKAPPY_IMAGE):$(ASKAPPY_TAG) [INDEPENDENT - builds from scratch]"
	@echo "  tostool: $(TOSTOOL_IMAGE):$(TOSTOOL_TAG) [DEPENDS on askappy-base]"
	@echo ""
	@echo "🏗️  Build Options:"
	@echo "  askappy-base: make build-askappy (registry) | make build-askappy-local (local)"
	@echo "  tostool: make build-tostool-local-base (local base) | make build-tostool-registry-base (registry base)"
	@echo ""
	@echo "🎯 Available Image Tags:"
	@echo "  askappy-base: $(ASKAPPY_TAG), $(ASKAPPY_TAG)-local, latest"
	@echo "  tostool: $(TOSTOOL_TAG), $(TOSTOOL_TAG)-local, $(TOSTOOL_TAG)-registry, latest"
	@echo ""
	@echo "🔧 Build Environment:"
	@echo "  Platforms: $(PLATFORMS)"
	@echo "  Git commit: $$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
	@echo "  Git tag: $$(git describe --tags --exact-match 2>/dev/null || echo 'none')"
	@echo "  Build date: $$(date -u +%Y-%m-%dT%H:%M:%SZ)"

status: ## Show current Docker status
	@echo "$(BLUE)Docker Status:$(NC)"
	@echo "Builder:"
	@docker buildx ls
	@echo ""
	@echo "askappy-base images:"
	@docker images $(ASKAPPY_IMAGE) || echo "No askappy-base images found"
	@echo ""
	@echo "tostool images:"
	@docker images $(TOSTOOL_IMAGE) || echo "No tostool images found"
	@echo ""
	@echo "Available image tags:"
	@echo "  askappy-base: $(ASKAPPY_TAG), $(ASKAPPY_TAG)-local"
	@echo "  tostool: $(TOSTOOL_TAG), $(TOSTOOL_TAG)-local, $(TOSTOOL_TAG)-registry"
	@echo ""
	@echo "Running containers:"
	@docker ps --filter ancestor=$(ASKAPPY_IMAGE) --filter ancestor=$(TOSTOOL_IMAGE) || echo "No running containers"

# Setup targets
setup: ## Initial setup for development
	@echo "$(BLUE)Setting up multi-project development environment...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)Created .env file from .env.example$(NC)"; \
	fi
	@docker buildx create --use --name askappy-builder 2>/dev/null || true
	@echo "$(GREEN)Multi-project setup complete!$(NC)"
	@echo "$(BLUE)Available projects:$(NC)"
	@make list-projects

# Release and CI/CD targets
tag-release: ## Tag and build release version (auto-detects git tag)
	@echo "$(BLUE)Building release version...$(NC)"
	@if git describe --tags --exact-match >/dev/null 2>&1; then \
		TAG=$$(git describe --tags --exact-match); \
		SHA=$$(git rev-parse --short HEAD); \
		BUILD_DATE=$$(date -u +%Y-%m-%dT%H:%M:%SZ); \
		echo "$(GREEN)Building release: $$TAG ($$SHA)$(NC)"; \
		echo "$(YELLOW)Building askappy-base...$(NC)"; \
		docker buildx build --platform linux/amd64,linux/arm64 \
			--build-arg BUILD_DATE=$$BUILD_DATE \
			--build-arg VCS_REF=$$SHA \
			--build-arg VERSION=$$TAG \
			--tag $(ASKAPPY_IMAGE):$$TAG \
			--tag $(ASKAPPY_IMAGE):$$TAG-$$SHA \
			--tag $(ASKAPPY_IMAGE):latest \
			--push \
			--file askappy-base/Dockerfile \
			askappy-base/; \
		echo "$(YELLOW)Building tostool...$(NC)"; \
		if [ -d "tostool/askap-repos" ] || make build-tostool-registry-base > /dev/null 2>&1; then \
			docker tag $(TOSTOOL_IMAGE):$(TOSTOOL_TAG)-registry $(TOSTOOL_IMAGE):$$TAG; \
			docker tag $(TOSTOOL_IMAGE):$(TOSTOOL_TAG)-registry $(TOSTOOL_IMAGE):$$TAG-$$SHA; \
			docker tag $(TOSTOOL_IMAGE):$(TOSTOOL_TAG)-registry $(TOSTOOL_IMAGE):latest; \
			docker push $(TOSTOOL_IMAGE):$$TAG; \
			docker push $(TOSTOOL_IMAGE):$$TAG-$$SHA; \
			docker push $(TOSTOOL_IMAGE):latest; \
		fi; \
		echo "$(GREEN)✅ Release $$TAG built and pushed!$(NC)"; \
	else \
		echo "$(RED)❌ No git tag found. Create a tag first: git tag v1.0.0 && git push origin v1.0.0$(NC)"; \
		exit 1; \
	fi

ci-build-askappy: ## Build askappy-base for CI/CD
	@echo "$(BLUE)Building askappy-base for CI/CD...$(NC)"
	docker buildx build --platform linux/amd64 \
		--build-arg BUILD_DATE=$$(date -u +%Y-%m-%dT%H:%M:%SZ) \
		--build-arg VCS_REF=$$(git rev-parse --short HEAD) \
		--build-arg VERSION=ci-$$(git rev-parse --short HEAD) \
		--tag $(ASKAPPY_IMAGE):$(ASKAPPY_TAG)-ci \
		--file askappy-base/Dockerfile \
		askappy-base/

ci-test-askappy: ci-build-askappy ## Test askappy-base CI build
	@echo "$(BLUE)Testing askappy-base CI build...$(NC)"
	docker run --rm $(ASKAPPY_IMAGE):$(ASKAPPY_TAG)-ci python3 -c "import casacore, numpy, astropy, pandas; print('✅ askappy-base CI test passed')"

# Future project enabling
enable-tostool: ## Enable tostool project (remove from gitignore)
	@echo "$(BLUE)Enabling tostool project...$(NC)"
	@sed -i '' '/^tostool\//d' .gitignore
	@echo "$(GREEN)tostool project enabled! You can now build it.$(NC)"
	@echo "$(YELLOW)Don't forget to commit the .gitignore change$(NC)"
