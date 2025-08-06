#!/bin/bash

#####################################################################
# TOSTOOL Build Script - Ubuntu 24.04 with Local Repository Cloning
# Securely builds tostool image using local Git credentials
#####################################################################

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Image configuration
REGISTRY="wasimraja81"
IMAGE_NAME="tostool-ubuntu-24.04"
TAG="2.28.0"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"
PLATFORMS="linux/amd64,linux/arm64"

# Repository configuration
REPO_VERSION="2.28.0"
REPOS_DIR="askap-repos"

# Build arguments
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
VCS_REF=$(git rev-parse --short HEAD)

log_info "Building TOSTOOL image: ${FULL_IMAGE}"
log_info "Repository version: ${REPO_VERSION}"
log_info "Build date: ${BUILD_DATE}"
log_info "VCS ref: ${VCS_REF}"

# Clean up any existing repos directory
if [[ -d "${REPOS_DIR}" ]]; then
    log_warn "Cleaning up existing ${REPOS_DIR} directory..."
    rm -rf "${REPOS_DIR}"
fi

# Create repositories directory
mkdir -p "${REPOS_DIR}"

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

# Clone all required ASKAP repositories using local credentials
log_info "Cloning ASKAP repositories using local Git credentials..."

cd "${REPOS_DIR}"

# Clone askap-dev and checkout specific version
clone_repo "ssh://git@bitbucket.csiro.au:7999/askapsdp/askap-dev.git" "askap-dev" "${REPO_VERSION}"

# Clone TOS repositories (use latest master/main)
clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-askap.git" "python-askap"
clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-parset" "python-parset"
clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-askap-interfaces" "python-askap-interfaces"
clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-iceutils" "python-iceutils"
clone_repo "ssh://git@bitbucket.csiro.au:7999/tos/python-askap-cli.git" "python-askap-cli"

cd ..

log_success "All repositories cloned successfully!"

# Create buildx builder if it doesn't exist
log_info "Setting up Docker buildx..."
docker buildx create --use --name tostool-builder 2>/dev/null || docker buildx use tostool-builder

# Build and push the image
log_info "Building and pushing TOSTOOL image..."
docker buildx build \
    --platform ${PLATFORMS} \
    --push \
    --tag ${FULL_IMAGE} \
    --tag ${REGISTRY}/${IMAGE_NAME}:latest \
    --file Dockerfile \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    --build-arg VCS_REF="${VCS_REF}" \
    --build-arg REPO_VERSION="${REPO_VERSION}" \
    .

# Clean up cloned repositories for security
log_info "Cleaning up cloned repositories..."
rm -rf "${REPOS_DIR}"

log_success "TOSTOOL image built and pushed successfully!"
log_info "Image: ${FULL_IMAGE}"
log_info "Also tagged as: ${REGISTRY}/${IMAGE_NAME}:latest"

# Test the image locally (optional)
log_info "Testing image locally..."
docker pull ${FULL_IMAGE}
docker run --rm ${FULL_IMAGE} python3 -c "import askap; import casacore; print('✅ TOSTOOL image working correctly!')"

log_success "Tostool Build completed successfully!"
