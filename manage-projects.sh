#!/bin/bash

#####################################################################
# Multi-Project Management Script
# Utilities for managing multiple Docker projects in this repository
#####################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_FILE="$SCRIPT_DIR/projects.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Function to list all projects
list_projects() {
    log_info "Available Projects:"
    echo ""
    
    # Check if yq is available for YAML parsing
    if command -v yq >/dev/null 2>&1; then
        yq eval '.projects | to_entries | .[] | "  " + .key + " (" + .value.enabled + "): " + .value.description' "$PROJECTS_FILE"
    else
        # Fallback to simple grep
        log_warn "yq not found, showing simplified list"
        grep -A 3 "^  [a-z]" "$PROJECTS_FILE" | grep -E "(^  [a-z]|description|enabled)" | sed 's/^  //'
    fi
    echo ""
}

# Function to enable a project
enable_project() {
    local project="$1"
    
    if [[ -z "$project" ]]; then
        log_error "Project name required"
        return 1
    fi
    
    log_info "Enabling project: $project"
    
    # Remove from gitignore if present
    if grep -q "^${project}/$" .gitignore 2>/dev/null; then
        sed -i.bak "/^${project}\/$/d" .gitignore
        log_success "Removed $project from .gitignore"
    fi
    
    # Update projects.yml if yq is available
    if command -v yq >/dev/null 2>&1; then
        yq eval ".projects.${project}.enabled = true" -i "$PROJECTS_FILE"
        log_success "Enabled $project in projects.yml"
    else
        log_warn "yq not found, please manually set enabled: true for $project in projects.yml"
    fi
    
    log_success "Project $project enabled!"
    log_info "Don't forget to commit the changes"
}

# Function to disable a project
disable_project() {
    local project="$1"
    
    if [[ -z "$project" ]]; then
        log_error "Project name required"
        return 1
    fi
    
    log_info "Disabling project: $project"
    
    # Add to gitignore if not present
    if ! grep -q "^${project}/$" .gitignore 2>/dev/null; then
        echo "" >> .gitignore
        echo "# Temporarily exclude $project until ready" >> .gitignore
        echo "${project}/" >> .gitignore
        log_success "Added $project to .gitignore"
    fi
    
    # Update projects.yml if yq is available
    if command -v yq >/dev/null 2>&1; then
        yq eval ".projects.${project}.enabled = false" -i "$PROJECTS_FILE"
        log_success "Disabled $project in projects.yml"
    else
        log_warn "yq not found, please manually set enabled: false for $project in projects.yml"
    fi
    
    log_success "Project $project disabled!"
}

# Function to show project status
show_status() {
    log_info "Project Status:"
    echo ""
    
    # List enabled projects
    log_info "Enabled Projects:"
    if command -v yq >/dev/null 2>&1; then
        yq eval '.projects | to_entries | .[] | select(.value.enabled == true) | "  ✅ " + .key + ": " + .value.image_name + ":" + .value.base_tag' "$PROJECTS_FILE"
    else
        log_warn "Install yq for detailed status"
    fi
    echo ""
    
    # List disabled projects
    log_info "Disabled Projects:"
    if command -v yq >/dev/null 2>&1; then
        yq eval '.projects | to_entries | .[] | select(.value.enabled == false) | "  🚧 " + .key + ": " + .value.image_name + ":" + .value.base_tag' "$PROJECTS_FILE"
    else
        log_warn "Install yq for detailed status"
    fi
    echo ""
}

# Function to validate project configuration
validate_projects() {
    log_info "Validating project configurations..."
    
    local errors=0
    
    # Check if projects.yml exists
    if [[ ! -f "$PROJECTS_FILE" ]]; then
        log_error "projects.yml not found"
        return 1
    fi
    
    # Check each enabled project directory
    if command -v yq >/dev/null 2>&1; then
        local enabled_projects
        enabled_projects=$(yq eval '.projects | to_entries | .[] | select(.value.enabled == true) | .key' "$PROJECTS_FILE")
        
        for project in $enabled_projects; do
            local context
            context=$(yq eval ".projects.${project}.context" "$PROJECTS_FILE")
            local dockerfile
            dockerfile=$(yq eval ".projects.${project}.dockerfile" "$PROJECTS_FILE")
            
            if [[ ! -d "$context" ]]; then
                log_error "Project directory not found: $context"
                ((errors++))
            fi
            
            if [[ ! -f "$context/$dockerfile" ]]; then
                log_error "Dockerfile not found: $context/$dockerfile"
                ((errors++))
            fi
        done
    else
        log_warn "Install yq for detailed validation"
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "All project configurations valid!"
    else
        log_error "Found $errors configuration errors"
        return 1
    fi
}

# Function to create a new project template
create_project() {
    local project="$1"
    local image_name="$2"
    
    if [[ -z "$project" ]] || [[ -z "$image_name" ]]; then
        log_error "Usage: $0 create-project PROJECT_NAME IMAGE_NAME"
        log_error "Example: $0 create-project my-tool wasimraja81/my-tool"
        return 1
    fi
    
    log_info "Creating new project: $project"
    
    # Create project directory
    mkdir -p "$project"
    
    # Create basic Dockerfile
    cat > "$project/Dockerfile" <<EOF
# Dockerfile for $project
ARG TARGETPLATFORM=linux/amd64
FROM --platform=\${TARGETPLATFORM} ubuntu:24.04

# Build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# Labels
LABEL org.opencontainers.image.title="$project" \\
      org.opencontainers.image.description="Docker image for $project" \\
      org.opencontainers.image.vendor="CSIRO" \\
      org.opencontainers.image.created="\${BUILD_DATE}" \\
      org.opencontainers.image.revision="\${VCS_REF}" \\
      org.opencontainers.image.version="\${VERSION}"

# Your project setup here
RUN apt-get update && apt-get install -y \\
    python3 \\
    python3-pip \\
    && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash"]
EOF
    
    # Create requirements.txt
    cat > "$project/requirements.txt" <<EOF
# Python dependencies for $project
# Add your packages here
numpy
matplotlib
EOF
    
    # Create build script
    cat > "$project/build.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

# Simple build script - can be enhanced as needed
IMAGE_NAME="${IMAGE_NAME:-localhost/PROJECT_NAME}"
TAG="${TAG:-latest}"

echo "Building ${IMAGE_NAME}:${TAG}..."
docker build -t "${IMAGE_NAME}:${TAG}" .
echo "Build complete!"
EOF
    
    # Make build script executable
    chmod +x "$project/build.sh"
    
    # Add to projects.yml (manual step for now)
    log_success "Project $project created!"
    log_info "Next steps:"
    log_info "1. Customize $project/Dockerfile"
    log_info "2. Add dependencies to $project/requirements.txt"
    log_info "3. Add project configuration to projects.yml"
    log_info "4. Enable the project: $0 enable $project"
}

# Main command handling
case "${1:-help}" in
    list|ls)
        list_projects
        ;;
    enable)
        enable_project "${2:-}"
        ;;
    disable)
        disable_project "${2:-}"
        ;;
    status)
        show_status
        ;;
    validate)
        validate_projects
        ;;
    create-project)
        create_project "${2:-}" "${3:-}"
        ;;
    help|--help|-h)
        echo "Multi-Project Management Script"
        echo ""
        echo "Usage: $0 COMMAND [ARGS]"
        echo ""
        echo "Commands:"
        echo "  list                    List all available projects"
        echo "  enable PROJECT          Enable a project (remove from gitignore)"
        echo "  disable PROJECT         Disable a project (add to gitignore)"
        echo "  status                  Show status of all projects"
        echo "  validate                Validate project configurations"
        echo "  create-project NAME IMG Create a new project template"
        echo "  help                    Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 list"
        echo "  $0 enable tostool"
        echo "  $0 disable tostool"
        echo "  $0 create-project my-tool wasimraja81/my-tool"
        ;;
    *)
        log_error "Unknown command: $1"
        log_info "Use '$0 help' for usage information"
        exit 1
        ;;
esac
