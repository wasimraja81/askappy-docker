#!/bin/bash

#####################################################################
# Build Script for TOSTOOL - Ubuntu 24.04 with Local Repository Cloning
# Securely builds tostool and aces-apps image using local Git credentials
#####################################################################

set -euo pipefail

# Source project_var.sh to extract variables from projects.yml
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_REPO_DIR="askap-tos-and-aces"

# Load helper to extract project variables
source "${SCRIPT_DIR}/../scripts/project_var.sh"

PROJECT="aces-apps"
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
    
    # Check if Dockerfile exists in script directory (or as specified)
    local dockerfile_path="$1"
    if [[ "$dockerfile_path" != /* ]]; then
        dockerfile_path="${SCRIPT_DIR}/$dockerfile_path"
    fi
    if [[ ! -f "$dockerfile_path" ]]; then
        log_error "Dockerfile not found: $dockerfile_path"
        exit 1
    fi
    # Check if required files exist
    log_success "All prerequisites met"
}

# Function to setup buildx builder
setup_buildx() {
    log_info "Setting up Docker buildx..."
    
    # Create and use a new builder if it doesn't exist
    if ! docker buildx inspect aces-apps-builder >/dev/null 2>&1; then
        log_info "Creating new buildx builder..."
        docker buildx create --name aces-apps-builder --use
    else
        log_info "Using existing buildx builder..."
        docker buildx use aces-apps-builder
    fi
    
    # Bootstrap the builder
    docker buildx inspect --bootstrap
    log_success "Buildx setup complete"
}

# Function to build, check, and optionally push image
build_check_push() {
    local dockerfile="${1:-Dockerfile}"
    # Ensure dockerfile is an absolute path, just like in check_prerequisites
    if [[ "$dockerfile" != /* ]]; then
        dockerfile="${SCRIPT_DIR}/$dockerfile"
    fi
    local check_builds="${2:-false}"
    local test_platform="${3:-linux/amd64}"
    local skip_test="${4:-false}"
    local skip_cleanup="${5:-false}"

    local full_tag="${IMAGE_NAME}:${BASE_TAG}"
    local latest_tag="${IMAGE_NAME}:${LATEST_TAG}"

    log_info "Building image: $full_tag"
    log_info "Dockerfile: $dockerfile"
    log_info "Build date: $BUILD_DATE"
    log_info "VCS ref: $VCS_REF"

    local build_args=(
        "--build-arg" "BUILD_DATE=${BUILD_DATE}"
        "--build-arg" "VCS_REF=${VCS_REF}"
        "--build-arg" "VERSION=${VERSION}"
        "--build-arg" "REPO_VERSION=${VERSION}"
        "--build-arg" "CPU_CORE_COUNT=$(nproc)"
    )

    if [[ "$check_builds" == true ]]; then
        log_info "[--check-builds] Only building and testing for platform: $test_platform (no push)"
        docker buildx build \
            --platform "$test_platform" \
            --load \
            --tag "$full_tag" \
            --file "$dockerfile" \
            "${build_args[@]}" \
            --progress=plain \
            --no-cache \
            .
    else
        log_info "Building for platforms: $PLATFORMS (multiarch, will push if successful)"
        docker buildx build \
            --platform "$PLATFORMS" \
            --push \
            --tag "$full_tag" \
            --file "$dockerfile" \
            "${build_args[@]}" \
            --progress=plain \
            --no-cache \
            .
    fi

    if [[ $? -eq 0 ]]; then
        log_success "Successfully built: $full_tag"
    else
        log_error "Build failed for: $full_tag"
        exit 1
    fi

    # For --check-builds, ensure the image is loaded locally for test
    if [[ "$check_builds" == true ]]; then
        if ! docker images "${IMAGE_NAME}" | grep -q "${BASE_TAG}"; then
            log_error "Image ${IMAGE_NAME}:${BASE_TAG} was not built successfully"
            exit 1
        fi
    fi

    log_info "Image ${IMAGE_NAME}:${BASE_TAG} built successfully"
    log_info "Running import test inside the built image..."
    mkdir -p "${SCRIPT_DIR}/build_log"
    touch "${SCRIPT_DIR}/build_log/import_test_formatted.txt"
    touch "${SCRIPT_DIR}/build_log/import_failures.txt"
    touch "${SCRIPT_DIR}/build_log/import_errors.log"
    set +e
    docker run \
        --rm \
        --platform "$test_platform" \
        -v "${SCRIPT_DIR}/import_directives.txt:/import_directives.txt:ro" \
        -v "${SCRIPT_DIR}/test_imports.py:/test_imports.py:ro" \
        -v "${SCRIPT_DIR}/build_log/import_test_formatted.txt:/import_test_formatted.txt" \
        -v "${SCRIPT_DIR}/build_log/import_failures.txt:/import_failures.txt" \
        -v "${SCRIPT_DIR}/build_log/import_errors.log:/import_errors.log" \
        -w / \
        "$full_tag" \
        bash -c 'python3 /test_imports.py /import_directives.txt' \
        > "${SCRIPT_DIR}/import_test.log" 2>&1
    set -e
    echo -e "\n\n================ Import Test Output Logs ================\n"
    echo -e "  Raw import test log:      ${SCRIPT_DIR}/import_test.log"
    echo -e "  Formatted summary:        ${SCRIPT_DIR}/build_log/import_test_formatted.txt"
    echo -e "  Machine-readable failures:${SCRIPT_DIR}/build_log/import_failures.txt"
    echo -e "  Detailed error log:       ${SCRIPT_DIR}/build_log/import_errors.log"
    echo -e "\n========================================================\n"
    log_info "See the above paths for import test results."
    fatal_failed=0
    if [[ -f "${SCRIPT_DIR}/build_log/import_failures.txt" ]]; then
        while IFS=$'\t' read -r desc severity err; do
            if [[ "$severity" == "FATAL" ]]; then
                fatal_failed=1
                break
            fi
        done < "${SCRIPT_DIR}/build_log/import_failures.txt"
    fi
    if [[ $fatal_failed -eq 0 ]]; then
        log_success "All FATAL imports succeeded."
    else
        log_error "FATAL import failures detected. See import_test.log and import_test_formatted.txt for details."
        cat import_test.log
        echo -e "\n\n================ Import Test Output Logs ================\n"
        echo -e "  Raw import test log:      ${SCRIPT_DIR}/import_test.log"
        echo -e "  Formatted summary:        ${SCRIPT_DIR}/build_log/import_test_formatted.txt"
        echo -e "  Machine-readable failures:${SCRIPT_DIR}/build_log/import_failures.txt"
        echo -e "  Detailed error log:       ${SCRIPT_DIR}/build_log/import_errors.log"
        echo -e "\n========================================================\n"
        echo -e "\n[HINT] To fix missing dependencies:"
        echo -e "  1. Check the error message above for the missing module (e.g., 'No module named ...')."
        echo -e "  2. Update the appropriate requirements.txt file (e.g., aces-apps/requirements.txt) to include the missing package."
        echo -e "  3. Rebuild the image."
        exit 0
    fi

    # Show image information
    show_image_info "$full_tag"
    # Test the image unless skipped
    if [[ "$skip_test" != true ]]; then
        test_image "$full_tag"
    fi
    # Cleanup unless skipped
    if [[ "$skip_cleanup" != true ]]; then
        cleanup
    fi

    # Only push if not --check-builds (buildx --push already handled the push)
    if [[ "$check_builds" != true ]]; then
        log_success "Image successfully built and pushed via buildx: $full_tag"
    else
        log_info "[--check-builds] Skipping push as requested."
    fi
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
    
    # Test basic Python and casacore functionality, and schedblock CLI inside the container
    docker run --rm --platform linux/amd64 "${tag}" bash -c '
cat <<EOF | python3
import sys
print(f"Python version: {sys.version}")
try:
    import casacore
    print("Casacore imported successfully")
    print(f"Casacore version: {casacore.__version__}")
except ImportError as e:
    print(f"Casacore import failed: {e}")
    sys.exit(1)
try:
    import numpy as np
    import astropy
    import pandas as pd
    print("Core scientific packages imported successfully")
except ImportError as e:
    print(f"Scientific package import failed: {e}")
    sys.exit(1)
print("All tests passed!")
EOF
echo "\nTesting schedblock CLI..."
schedblock info -h
'
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
    local TMP_REPO_DIR="${TMP_REPO_DIR}"
    local ASKAP_DEV_VERSION_TO_BUILD_FROM="2.28.0"
    local ACES_APPS_VERSION_TO_BUILD_FROM="1.5.9"

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
    clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-footprint" "python-footprint"
    clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-askap-interfaces" "python-askap-interfaces"
    clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-iceutils" "python-iceutils"
    clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-askap-cli.git" "python-askap-cli"
    clone_repo "https://bitbucket.csiro.au/scm/aces/aces-apps.git" "aces-apps" "${ACES_APPS_VERSION_TO_BUILD_FROM}"


    cd ..

    log_success "All repositories cloned successfully!"
}

# Function to apply patches to cloned repositories
apply_patches() {
    local TMP_REPO_DIR="${TMP_REPO_DIR}"
    local PATCHES_DIR="${SCRIPT_DIR}/patches"
    
    log_info "Applying patches to cloned repositories..."
    
    # Check if patches directory exists
    if [[ ! -d "${PATCHES_DIR}" ]]; then
        log_info "No patches directory found at ${PATCHES_DIR}, skipping patch application"
        return 0
    fi
    
    # Apply Python 3.10 compatibility patch to python-iceutils
    local iceutils_patch="${PATCHES_DIR}/python-iceutils-python310-compat.patch"
    if [[ -f "${iceutils_patch}" ]]; then
        log_info "Applying Python 3.10 compatibility patch to python-iceutils..."
        cd "${TMP_REPO_DIR}/python-iceutils"
        
        if patch -p1 < "${iceutils_patch}"; then
            log_success "Successfully applied python-iceutils Python 3.10 compatibility patch"
        else
            log_error "Failed to apply python-iceutils Python 3.10 compatibility patch"
            return 1
        fi
        
        cd - > /dev/null
    else
        log_warn "Python 3.10 compatibility patch not found: ${iceutils_patch}"
    fi
    
    log_success "All patches applied successfully!"
}

# Main execution
main() {
    local dockerfile="Dockerfile"
    local skip_test=false
    local skip_cleanup=false
    local check_builds=false
    local test_platform="linux/amd64"
    local apply_patches=false

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
            --check-builds)
                check_builds=true
                shift
                ;;
            --test-platform)
                test_platform="$2"
                shift 2
                ;;
            --apply-patches)
                apply_patches=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --dockerfile FILE    Use specific Dockerfile (default: Dockerfile)"
                echo "  --skip-test         Skip image testing"
                echo "  --skip-cleanup      Skip cleanup"
                echo "  --check-builds      Only build and test for a single platform, do not push"
                echo "  --test-platform PLAT  Platform for local test (default: linux/amd64)"
                echo "  --apply-patches     Apply compatibility patches to cloned repositories"
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

    # Apply patches to cloned repositories if requested
    if [[ "$apply_patches" == true ]]; then
        apply_patches
    else
        log_info "Skipping patch application (use --apply-patches to enable)"
    fi

    log_info "Starting Docker build process..."
    log_info "Using dockerfile: $dockerfile"

    # Execute build steps
    check_prerequisites "$dockerfile"
    setup_buildx

    # Record start time
    local start_time=$(date +%s)

    build_check_push "$dockerfile" "$check_builds" "$test_platform" "$skip_test" "$skip_cleanup"

    # Clean up cloned repositories for security (should be handled in build_check_push, but keep for safety)
    log_info "Cleaning up cloned repositories..."
    rm -rf "askap-tos"

    log_success "All operations completed successfully!"
    log_info "Image available at: ${IMAGE_NAME}:${BASE_TAG}"
    log_info "Latest tag: ${IMAGE_NAME}:${LATEST_TAG}"
}

# Run main function with all arguments
main "$@"

