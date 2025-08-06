# syntax=docker/dockerfile:1

#####################################################################
# TOSTOOL Docker Image - Ubuntu 24.04 with ASKAP TOS Tools
# Built on askappy-base with casacore and scientific computing stack
#####################################################################

ARG TARGETPLATFORM=linux/amd64
FROM --platform=${TARGETPLATFORM} wasimraja81/askappy-ubuntu-24.04:base-mpich-casacore-3.6.1

ARG TARGETPLATFORM
ARG DEBIAN_FRONTEND=noninteractive

# Build-time metadata
ARG BUILD_DATE
ARG VCS_REF
ARG REPO_VERSION  # Must be provided by build.sh or build system


# TOSTOOL specific build arguments
ARG REPO_NAME=tostool

# Build and install directories
ARG BUILD_DIR=/tmp/
ARG INSTALL_DIR=/usr/local/askappy/

# Set working directory
WORKDIR /

# Set timezone (inherited from base but ensure consistency)
ENV TZ=Etc/UTC

# You may want to define the repo version as an environment variable
ENV TOSTOOL_VERSION="${REPO_VERSION}"

# Install TOSTOOL specific Python requirements
COPY requirements.txt /tmp/tostool-requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/tostool-requirements.txt \
    && rm /tmp/tostool-requirements.txt

# Copy pre-cloned ASKAP repositories (cloned locally with user credentials)
# These should be cloned by the build script before docker build
COPY askap-repos/askap-dev ${BUILD_DIR}/askap-dev
COPY askap-repos/python-askap ${BUILD_DIR}/python-askap
COPY askap-repos/python-parset ${BUILD_DIR}/python-parset
COPY askap-repos/python-askap-interfaces ${BUILD_DIR}/python-askap-interfaces
COPY askap-repos/python-iceutils ${BUILD_DIR}/python-iceutils
COPY askap-repos/python-askap-cli ${BUILD_DIR}/python-askap-cli

# Build and install ASKAP tools
RUN echo "Installing ASKAP tools from local copies..." \
    # Create install directory
    && mkdir -p ${INSTALL_DIR} \
    # Install python packages with Ubuntu 24.04 compatibility
    && echo "Installing python-askap..." \
    && pip3 install --break-system-packages ${BUILD_DIR}/python-askap \
    && echo "Installing python-parset..." \
    && pip3 install --break-system-packages ${BUILD_DIR}/python-parset \
    && echo "Installing python-askap-interfaces..." \
    && pip3 install --break-system-packages ${BUILD_DIR}/python-askap-interfaces \
    && echo "Installing python-iceutils..." \
    && pip3 install --break-system-packages ${BUILD_DIR}/python-iceutils \
    && echo "Installing python-askap-cli..." \
    && pip3 install --break-system-packages ${BUILD_DIR}/python-askap-cli \
    # Copy ICE configuration from askap-dev
    && cp ${BUILD_DIR}/askap-dev/config/tos-ice.cfg ${INSTALL_DIR} \
    && echo "ASKAP tools installation completed successfully" \
    # Clean up build artifacts
    && rm -rf ${BUILD_DIR} \
    && echo "Build cleanup completed"

# Set ICE configuration environment variable
ENV ICE_CONFIG=${INSTALL_DIR}/tos-ice.cfg

# Copy build files for record keeping
RUN mkdir -p /build-records
COPY Dockerfile /build-records/
COPY requirements.txt /build-records/

# Metadata labels
LABEL org.opencontainers.image.title="tostool" \
      org.opencontainers.image.description="ASKAP TOS tools needed by ASKAPpipeline for various services and askap-python tools" \
      org.opencontainers.image.version="${REPO_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="CSIRO" \
      org.opencontainers.image.authors="Wasim Raja <Wasim.Raja@csiro.au>" \
      repo.name="${REPO_NAME}" \
      repo.version="${REPO_VERSION}" \
      repo.maintainer.name="Wasim Raja" \
      repo.maintainer.email="Wasim.Raja@csiro.au" \
      tostool.version="${REPO_VERSION}" \
      base.image="wasimraja81/askappy-ubuntu-24.04:base-mpich-casacore-3.6.1"

# Health check to verify ASKAP tools are properly installed
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import askap; import casacore; print('TOSTOOL OK')" || exit 1

CMD ["/bin/bash"]
