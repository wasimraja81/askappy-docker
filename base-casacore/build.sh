#!/bin/bash

#####################################################################
# Build Script for base-casacore - Ubuntu 24.04 with MPICH and Casacore
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

# Source project_var.sh to extract variables from projects.yml
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
source "${ROOT_DIR}/scripts/project_var.sh"

# Extract variables for base-casacore
REGISTRY=$(project_var base-casacore registry)
IMAGE_NAME=$(project_var base-casacore image_name)
RAW_TAG=$(project_var base-casacore base_tag)
DATE=$(date +%Y%m%d)
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
TAG="${RAW_TAG}-${DATE}-${SHA}"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"
PLATFORMS=$(project_var base-casacore platforms)

BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
VCS_REF=$(git rev-parse --short HEAD)

log_info "Building base-casacore image: ${FULL_IMAGE}"
log_info "Build date: ${BUILD_DATE}"
log_info "VCS ref: ${VCS_REF}"

# Create buildx builder if it doesn't exist
log_info "Setting up Docker buildx..."
docker buildx create --use --name base-casacore-builder 2>/dev/null || docker buildx use base-casacore-builder

# Build and push the image
log_info "Building and pushing base-casacore image..."
docker buildx build \
    --platform ${PLATFORMS} \
    --push \
    --tag ${FULL_IMAGE} \
    --tag ${REGISTRY}/${IMAGE_NAME}:latest \
    --file Dockerfile \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    --build-arg VCS_REF="${VCS_REF}" \
    .

log_success "base-casacore image built and pushed successfully!"
log_info "Image: ${FULL_IMAGE}"
log_info "Also tagged as: ${REGISTRY}/${IMAGE_NAME}:latest"
