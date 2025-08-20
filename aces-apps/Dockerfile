# syntax=docker/dockerfile:1

#####################################################################
# TOSTOOL Docker Image - Ubuntu 24.04 with ASKAP TOS Tools
# Built on askappy-base with casacore and scientific computing stack
#####################################################################
ARG BASE_CASACORE_VERSION=casacore-3.7.1-20250810-607f488
ARG TARGETPLATFORM=linux/amd64
FROM --platform=${TARGETPLATFORM} wasimraja81/base-casacore:${BASE_CASACORE_VERSION} as casacore-base

ARG TARGETPLATFORM
ARG DEBIAN_FRONTEND=noninteractive

# Build-time metadata
ARG BUILD_DATE
ARG VCS_REF
ARG REPO_VERSION  # Must be provided by build.sh or build system


# TOSTOOL specific build arguments
ARG REPO_NAME=aces-apps

# Build and install directories
ARG BUILD_DIR=_/build
ARG INSTALL_DIR=/usr/local/askappy/

# Set working directory
WORKDIR /

# Set timezone (inherited from base but ensure consistency)
ENV TZ=Etc/UTC

# You may want to define the repo version as an environment variable
ENV TOSTOOL_VERSION="${REPO_VERSION}"

# Install less pager utility
RUN apt-get update && apt-get install -y less && rm -rf /var/lib/apt/lists/*

# Install TOSTOOL specific Python requirements



# Install typing_extensions for Python 3.10 compatibility before ASKAP tools
RUN python3 -m pip install typing_extensions>=4.0

COPY requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install --no-build-isolation -r /tmp/requirements.txt

# Copy pre-cloned ASKAP repositories (cloned locally with user credentials)
# These should be cloned by the build script before docker build
# Note: Patches are applied by build.sh before docker build
COPY askap-tos-and-aces/askap-dev ${BUILD_DIR}/askap-dev
COPY askap-tos-and-aces/python-askap ${BUILD_DIR}/python-askap
COPY askap-tos-and-aces/python-parset ${BUILD_DIR}/python-parset
COPY askap-tos-and-aces/python-footprint ${BUILD_DIR}/python-footprint
COPY askap-tos-and-aces/python-askap-interfaces ${BUILD_DIR}/python-askap-interfaces
COPY askap-tos-and-aces/python-iceutils ${BUILD_DIR}/python-iceutils
COPY askap-tos-and-aces/python-askap-cli ${BUILD_DIR}/python-askap-cli
COPY askap-tos-and-aces/aces-apps ${BUILD_DIR}/aces-apps


# Build and install TOS/ASKAP tools (excluding aces-apps)
RUN echo "Installing TOS/ASKAP tools from local copies..." \
    && python3 -m pip install --upgrade pip \
    && mkdir -p ${INSTALL_DIR} \
    && echo "Installing python-askap..." \
    && pip3 install ${BUILD_DIR}/python-askap \
    && echo "Installing python-parset..." \
    && pip3 install ${BUILD_DIR}/python-parset \
    && echo "Installing python-footprint..." \
    && pip3 install ${BUILD_DIR}/python-footprint \
    && echo "Installing python-askap-interfaces..." \
    && pip3 install ${BUILD_DIR}/python-askap-interfaces \
    && echo "Installing python-iceutils..." \
    && pip3 install ${BUILD_DIR}/python-iceutils \
    && echo "Installing python-askap-cli..." \
    && pip3 install ${BUILD_DIR}/python-askap-cli \
    && cp ${BUILD_DIR}/askap-dev/config/tos-ice.cfg ${INSTALL_DIR}

# Install setuptools and wheel after TOS/ASKAP tools
RUN python3 -m pip install --upgrade setuptools wheel

# Now build and install aces-apps in isolation
RUN echo "Installing aces-apps..." \
    && cd ${BUILD_DIR}/aces-apps \
    && pip3 install poetry \
    && pip3 install pendulum \
    && pip3 install -e . \
    && cp scripts/*.sh /usr/local/bin/. \
    && cp tests/* /usr/local/bin/. \
    && echo "aces-apps installation completed successfully" \
    && rm -rf ${BUILD_DIR} \
    && echo "Build cleanup completed"

# Set ICE configuration environment variable
ENV ICE_CONFIG=${INSTALL_DIR}/tos-ice.cfg

# Copy build files for record keeping
RUN mkdir -p /build-records
COPY Dockerfile /build-records

# Metadata labels
LABEL org.opencontainers.image.title="aces-apps" \
      org.opencontainers.image.description="ACES tools needed by ASKAPpipeline for various services and askap-python tools" \
      org.opencontainers.image.version="${REPO_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="CSIRO" \
      org.opencontainers.image.authors="Wasim Raja <Wasim.Raja@csiro.au>" \
      repo.name="${REPO_NAME}" \
      repo.version="${REPO_VERSION}" \
      repo.maintainer.name="Wasim Raja" \
      repo.maintainer.email="Wasim.Raja@csiro.au" \
      aces-apps.version="${REPO_VERSION}" \
      base.image="wasimraja81/askappy-ubuntu-24.04:aces-apps-${REPO_VERSION}" 

RUN ln -sf /usr/bin/python3 /usr/local/bin/python

# Health check to verify ASKAP tools are properly installed
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import askap; import casacore; import mpi4py; print('TOSTOOL OK')" || exit 1

CMD ["/bin/bash"]
