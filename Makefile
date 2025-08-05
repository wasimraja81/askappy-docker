# Multi-Project Makefile for askappy-docker repository
# Supports multiple independent Docker projects

.PHONY: help build test push clean list-projects

# Project configurations
ASKAPPY_IMAGE := wasimraja81/askappy-ubuntu-24.04
ASKAPPY_TAG := base-mpich-casacore-3.6.1
TOSTOOL_IMAGE := wasimraja81/tostool-ubuntu-22.04
TOSTOOL_TAG := mpich-casacore-3.6.1

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
	@echo "  $(GREEN)build-askappy$(NC)          Build askappy-base image"
	@echo "  $(GREEN)build-tostool$(NC)          Build tostool image"
	@echo "  $(GREEN)test-askappy$(NC)           Test askappy-base image"
	@echo "  $(GREEN)push-askappy$(NC)           Push askappy-base image"
	@echo ""
	@echo "Examples:"
	@echo "  make build-askappy      # Build askappy-base project"
	@echo "  make test-askappy       # Test askappy-base project"
	@echo "  make build-all          # Build all enabled projects"

# Project listing
list-projects: ## List all available projects
	@echo "$(BLUE)Available Projects:$(NC)"
	@echo "  $(GREEN)askappy-base$(NC) - Base image with casacore ($(ASKAPPY_IMAGE):$(ASKAPPY_TAG))"
	@echo "  $(YELLOW)tostool$(NC)      - TOSTOOL processing tools ($(TOSTOOL_IMAGE):$(TOSTOOL_TAG)) [disabled]"

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
		askappy-base/

test-askappy: ## Test askappy-base Docker image
	@echo "$(BLUE)Testing askappy-base...$(NC)"
	docker run --rm --platform linux/amd64 $(ASKAPPY_IMAGE):$(ASKAPPY_TAG) python3 -c "\
		import casacore, numpy, astropy, pandas, matplotlib; \
		print('✅ askappy-base test passed')"

push-askappy: ## Push askappy-base to Docker Hub
	@echo "$(BLUE)Pushing askappy-base...$(NC)"
	docker push $(ASKAPPY_IMAGE):$(ASKAPPY_TAG)
	docker push $(ASKAPPY_IMAGE):latest

# Tostool specific targets (disabled for now)
build-tostool: ## Build tostool Docker image [DISABLED]
	@echo "$(YELLOW)tostool build is currently disabled$(NC)"
	@echo "Enable by removing .gitignore entry for tostool/"

test-tostool: ## Test tostool Docker image [DISABLED]
	@echo "$(YELLOW)tostool test is currently disabled$(NC)"

push-tostool: ## Push tostool to Docker Hub [DISABLED]
	@echo "$(YELLOW)tostool push is currently disabled$(NC)"

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
	@echo "Enabled projects:"
	@echo "  - askappy-base: $(ASKAPPY_IMAGE):$(ASKAPPY_TAG)"
	@echo "Disabled projects:"
	@echo "  - tostool: $(TOSTOOL_IMAGE):$(TOSTOOL_TAG)"
	@echo "Platforms: $(PLATFORMS)"
	@echo "Git commit: $$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
	@echo "Build date: $$(date -u +%Y-%m-%dT%H:%M:%SZ)"

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

# CI/CD targets
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
	docker run --rm $(ASKAPPY_IMAGE):$(ASKAPPY_TAG)-ci python3 -c "\
		import casacore, numpy, astropy, pandas; \
		print('✅ askappy-base CI test passed')"

# Future project enabling
enable-tostool: ## Enable tostool project (remove from gitignore)
	@echo "$(BLUE)Enabling tostool project...$(NC)"
	@sed -i '' '/^tostool\/$/d' .gitignore
	@echo "$(GREEN)tostool project enabled! You can now build it.$(NC)"
	@echo "$(YELLOW)Don't forget to commit the .gitignore change$(NC)"
