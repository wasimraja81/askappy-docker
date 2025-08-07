#!/bin/bash

#####################################################################
# Build Script for base-mpich - Ubuntu 24.04 with MPICH only
#####################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load helper to extract project variables
source "${SCRIPT_DIR}/../scripts/project_var.sh"

PROJECT="base-mpich"
DATE=$(date +%Y%m%d)
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Use the correct function name from project_var.sh
IMAGE_NAME=$(get_project_var $PROJECT image_name)
RAW_BASE_TAG=$(get_project_var $PROJECT base_tag)
BASE_TAG="${RAW_BASE_TAG}-${DATE}-${SHA}"
LATEST_TAG="${PROJECT}-latest"

# Build metadata
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
VCS_REF="$SHA"
VERSION="${BASE_TAG}"

# Platform support
PLATFORMS=$(get_project_var $PROJECT platforms)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running or not installed"
        exit 1
    fi
    
    # Check if buildx is available
    if ! docker buildx version >/dev/null 2>&1; then
        log_error "Docker buildx is not available"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [[ ! -f "Dockerfile" ]] && [[ ! -f "Dockerfile.improved" ]]; then
        log_error "No Dockerfile found in current directory"
        exit 1
    fi
    
    # Check if required files exist
    local required_files=("requirements.txt")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required file not found: $file"
            exit 1
        fi
    done
    
    log_success "All prerequisites met"
}

# Function to setup buildx builder
setup_buildx() {
    log_info "Setting up Docker buildx..."
    
    # Create and use a new builder if it doesn't exist
    if ! docker buildx inspect askappy-builder >/dev/null 2>&1; then
        log_info "Creating new buildx builder..."
        docker buildx create --name askappy-builder --use
    else
        log_info "Using existing buildx builder..."
        docker buildx use askappy-builder
    fi
    
    # Bootstrap the builder
    docker buildx inspect --bootstrap
    log_success "Buildx setup complete"
}

# Function to build and push image
build_and_push() {
    local dockerfile="${1:-Dockerfile}"

    local full_tag="${IMAGE_NAME}:${BASE_TAG}"
    local latest_tag="${IMAGE_NAME}:${LATEST_TAG}"

    log_info "Building and pushing: $full_tag"
    log_info "Dockerfile: $dockerfile"
    log_info "Platforms: $PLATFORMS"
    log_info "Build date: $BUILD_DATE"
    log_info "VCS ref: $VCS_REF"

    # Build arguments
    local build_args=(
        "--build-arg" "BUILD_DATE=${BUILD_DATE}"
        "--build-arg" "VCS_REF=${VCS_REF}"
        "--build-arg" "VERSION=${VERSION}"
        "--build-arg" "CPU_CORE_COUNT=$(nproc)"
    )

    # Build and push
    docker buildx build \
        --platform "${PLATFORMS}" \
        --push \
        --tag "${full_tag}" \
        --tag "${latest_tag}" \
        --file "${dockerfile}" \
        "${build_args[@]}" \
        --progress=plain \
        .

    log_success "Successfully built and pushed: $full_tag"
    log_success "Successfully built and pushed: $latest_tag"
}

# Function to show image information
show_image_info() {
    local tag="$1"
    log_info "Image information for: $tag"
    
    # Show image layers and size (only for current platform)
    docker buildx imagetools inspect "${tag}" || true
}

# Function to clean up old images
cleanup() {
    log_info "Cleaning up unused Docker images..."
    docker image prune -f || true
    docker buildx prune -f || true
    log_success "Cleanup complete"
}

# Main execution
main() {
    local dockerfile="Dockerfile"
    local skip_test=false
    local skip_cleanup=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dockerfile)
                dockerfile="$2"
                shift 2
                ;;
            --skip-test)
                skip_test=true
                shift
                ;;
            --skip-cleanup)
                skip_cleanup=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --dockerfile FILE    Use specific Dockerfile (default: Dockerfile)"
                echo "  --skip-test         Skip image testing"
                echo "  --skip-cleanup      Skip cleanup"
                echo "  --help, -h          Show this help"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "Starting Docker build process..."
    log_info "Using dockerfile: $dockerfile"
    
    # Execute build steps
    check_prerequisites
    setup_buildx
    
    # Record start time
    local start_time=$(date +%s)
    
    build_and_push "$dockerfile"
    
    # Calculate build time
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    log_info "Build completed in ${build_time} seconds"
    
    # Show image information
    show_image_info "${IMAGE_NAME}:${BASE_TAG}"

    # Cleanup unless skipped
    if [[ "$skip_cleanup" != true ]]; then
        cleanup
    fi

    log_info "Image available at: ${IMAGE_NAME}:${BASE_TAG}"
    log_info "Latest tag: ${IMAGE_NAME}:${LATEST_TAG}"

    log_info "Building base-mpich image: ${IMAGE_NAME}:${BASE_TAG}"
    log_info "Build date: ${BUILD_DATE}"
    log_info "VCS ref: ${VCS_REF}"
}

# Run main function with all arguments
main "$@"
