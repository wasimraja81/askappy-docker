#!/bin/bash

#####################################################################
# Build Script for TOSTOOL - Ubuntu 24.04 with Local Repository Cloning
# Securely builds tostool image using local Git credentials
#####################################################################

set -euo pipefail

# Source project_var.sh to extract variables from projects.yml
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load helper to extract project variables
source "${SCRIPT_DIR}/../scripts/project_var.sh"

PROJECT="tostool"
DATE=$(date +%Y%m%d)
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

IMAGE_NAME=$(get_project_var "$PROJECT" image_name)
RAW_BASE_TAG=$(get_project_var "$PROJECT" base_tag)
BASE_TAG="${RAW_BASE_TAG}-${DATE}-${SHA}"
LATEST_TAG="${PROJECT}-latest"

# Build metadata
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
VCS_REF="$SHA"
VERSION="${BASE_TAG}"

# Platform support
PLATFORMS="linux/amd64,linux/arm64"

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
    log_success "All prerequisites met"
}

# Function to setup buildx builder
setup_buildx() {
    log_info "Setting up Docker buildx..."
    
    # Create and use a new builder if it doesn't exist
    if ! docker buildx inspect tostool-builder >/dev/null 2>&1; then
        log_info "Creating new buildx builder..."
        docker buildx create --name tostool-builder --use
    else
        log_info "Using existing buildx builder..."
        docker buildx use tostool-builder
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
        "--build-arg" "REPO_VERSION=${VERSION}"
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

# Function to test the built image
test_image() {
    local tag="$1"
    log_info "Testing image: $tag"
    
    # Test basic Python and casacore functionality
    docker run --rm --platform linux/amd64 "${tag}" python3 -c "
import sys
print(f'Python version: {sys.version}')
try:
    import casacore
    print('Casacore imported successfully')
    print(f'Casacore version: {casacore.__version__}')
except ImportError as e:
    print(f'Casacore import failed: {e}')
    sys.exit(1)
    
try:
    import numpy as np
    import astropy
    import pandas as pd
    print('Core scientific packages imported successfully')
except ImportError as e:
    print(f'Scientific package import failed: {e}')
    sys.exit(1)
    
print('All tests passed!')
"
    
    if [[ $? -eq 0 ]]; then
        log_success "Image test passed"
    else
        log_error "Image test failed"
        exit 1
    fi
}

# Function to clean up old images
# Function to clean up old images
cleanup() {
    log_info "Cleaning up unused Docker images..."
    docker image prune -f || true
    docker buildx prune -f || true
    log_success "Cleanup complete"
}

# Function to clone repository with error handling
clone_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local checkout_ref="${3:-master}"
    
    log_info "Cloning $(basename ${repo_url}) to ${target_dir}..."
    
    if git clone --recurse-submodules "${repo_url}" "${target_dir}"; then
        if [[ "${checkout_ref}" != "master" && "${checkout_ref}" != "main" ]]; then
            cd "${target_dir}"
            git checkout "${checkout_ref}"
            cd ..
        fi
        log_success "Successfully cloned $(basename ${repo_url})"
    else
        log_error "Failed to clone ${repo_url}"
        exit 1
    fi
}


# Function to clone all required ASKAP repositories
clone_all_repos() {
    local TMP_REPO_DIR="askap-tos"
    local ASKAP_DEV_VERSION_TO_BUILD_FROM="2.28.0"

    # Clean up any existing repos directory
    if [[ -d "${TMP_REPO_DIR}" ]]; then
        log_warn "Cleaning up existing ${TMP_REPO_DIR} directory..."
        rm -rf "${TMP_REPO_DIR}"
    fi

    # Create repositories directory
    mkdir -p "${TMP_REPO_DIR}"

    # Clone all required ASKAP repositories using local credentials
    log_info "Cloning ASKAP repositories using local Git credentials..."

    cd "${TMP_REPO_DIR}"

    # Clone askap-dev and checkout specific version
    clone_repo "ssh://git@bitbucket.csiro.au:7999/askapsdp/askap-dev.git" "askap-dev" "${ASKAP_DEV_VERSION_TO_BUILD_FROM}"

    # Clone TOS repositories (use latest master/main)
    clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-askap.git" "python-askap"
    clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-parset" "python-parset"
    clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-askap-interfaces" "python-askap-interfaces"
    clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-iceutils" "python-iceutils"
    clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-askap-cli.git" "python-askap-cli"

    cd ..

    log_success "All repositories cloned successfully!"
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

    # Clone all required repos before building
    clone_all_repos

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

    # Test the image unless skipped
    if [[ "$skip_test" != true ]]; then
        test_image "${IMAGE_NAME}:${BASE_TAG}"
    fi

    # Cleanup unless skipped
    if [[ "$skip_cleanup" != true ]]; then
        cleanup
    fi

    # Clean up cloned repositories for security
    log_info "Cleaning up cloned repositories..."
    rm -rf "askap-tos"

    log_success "All operations completed successfully!"
    log_info "Image available at: ${IMAGE_NAME}:${BASE_TAG}"
    log_info "Latest tag: ${IMAGE_NAME}:${LATEST_TAG}"
}

# Run main function with all arguments
main "$@"

