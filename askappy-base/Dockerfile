# syntax=docker/dockerfile:1

#####################################################################
# Multi-stage build for askappy base image with casacore
# Improved version with better practices while maintaining all libs
#####################################################################

ARG UBUNTU_VERSION=24.04
ARG TARGETPLATFORM=linux/amd64

#####################################################################
# Stage 1: Build dependencies and tools
#####################################################################
FROM --platform=${TARGETPLATFORM} ubuntu:${UBUNTU_VERSION} as builder

ARG TARGETPLATFORM
ARG DEBIAN_FRONTEND=noninteractive

# Build-time metadata
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# Set timezone early
ENV TZ=Etc/UTC

# Install build dependencies in a single layer with cleanup
RUN apt-get update -qq \
    && apt-get install -yq tzdata \
    && ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && apt-get -y --no-install-recommends install \
        # Development tools
        git \
        wget \
        build-essential \
        cmake \
        gdb \
        g++ \
        gfortran \
        libgfortran5 \
        flex \
        bison \
        # System libraries
        ca-certificates \
        libc6 \
        libssl-dev \
        libffi-dev \
        libncurses-dev \
        libreadline-dev \
        # MPI and parallel computing
        libhwloc-dev \
        libibverbs-dev \
        libopenmpi-dev \
        # Python development
        python3-dev \
        python3-pip \
        python3-pyparsing \
        python3-numpy \
        python3-setuptools \
        # Scientific computing libraries
        libblas-dev \
        liblapacke-dev \
        libcfitsio-dev \
        libpthread-stubs0-dev \
        libgsl-dev \
        wcslib-dev \
        libfftw3-dev \
        # Image processing
        imagemagick \
        libmagickcore-dev \
        libmagickwand-dev \
        libmagic-dev \
        # Other development libraries
        libbz2-dev \
        libclang-dev \
        libboost-python-dev \
        # X11 and GUI (if needed for your workflows)
        libx11-dev \
        # Archive tools
        fuse \
        libfuse2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Build directories
ARG BUILD_DIR=/_build
ARG MEASURES_DATA="/_build/measures_data"
ARG INSTALL_DIR=/_install

RUN mkdir -p ${INSTALL_DIR} ${BUILD_DIR} ${MEASURES_DATA}

# Install basic Python packages (skip pip upgrade, use system pip 24.0)
RUN pip3 install setuptools --break-system-packages \
    && pip3 install wheel --break-system-packages 

#####################################################################
# Stage 2: Build MPICH (isolated layer)
#####################################################################
FROM builder as mpich-builder

ARG MPICH_VERSION="4.3.1"
ARG CPU_CORE_COUNT=4
ARG MPICH_CONFIGURE_OPTIONS="--enable-fast=all,O3 --with-device=ch4:ofi --prefix=/usr/local FFLAGS=-fallow-argument-mismatch"

RUN cd ${BUILD_DIR} \
    && wget -q https://www.mpich.org/static/downloads/${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz \
    && tar xzf mpich-${MPICH_VERSION}.tar.gz \
    && cd mpich-${MPICH_VERSION} \
    && ./configure ${MPICH_CONFIGURE_OPTIONS} \
    && make -j${CPU_CORE_COUNT} \
    && make install \
    && ldconfig \
    && cd / \
    && rm -rf ${BUILD_DIR}/mpich-${MPICH_VERSION}*

#####################################################################
# Stage 3: Build Casacore (isolated layer)
#####################################################################
FROM mpich-builder as casacore-builder

ARG CASACORE_VERSION=v3.6.1

# Download measures data
RUN cd ${MEASURES_DATA} \
    && wget -q ftp://ftp.astron.nl/outgoing/Measures/WSRT_Measures.ztar \
    && tar xf *.ztar \
    && rm *.ztar

# Build casacore
RUN cd ${BUILD_DIR} \
    && git clone --depth 1 --branch ${CASACORE_VERSION} https://github.com/casacore/casacore.git \
    && cd casacore \
    && mkdir build \
    && cd build \
    && cmake \
        -DDATA_DIR=${MEASURES_DATA} \
        -DUSE_OPENMP=OFF \
        -DBUILD_PYTHON3=ON \
        -DUSE_THREADS=ON \
        -DCMAKE_BUILD_TYPE=Release \
        .. \
    && make -j${CPU_CORE_COUNT} install \
    && ldconfig \
    && cd / \
    && rm -rf ${BUILD_DIR}/casacore

#####################################################################
# Stage 4: Build python-casacore (isolated layer) 
#####################################################################
FROM casacore-builder as python-casacore-builder

# Minimal environment variables to guide python-casacore's CMake
ENV CMAKE_PREFIX_PATH=/usr/local:/usr/lib/x86_64-linux-gnu

# Install Python packages (including python-casacore) 
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt \
    && pip3 install --default-timeout=120 --no-binary python-casacore --break-system-packages python-casacore \
    && rm /tmp/requirements.txt

# Clean up build artifacts to reduce image size
RUN rm -rf ${BUILD_DIR}

# Define the measures data area in the root's home area:
ARG CASA_CONFIG_DIR="/root/.casa"
RUN mkdir -p ${CASA_CONFIG_DIR}
COPY config.py ${CASA_CONFIG_DIR}/.

# Replicate the policy for ImageMagick from Setonix setup
ADD ImageMagick-7_on_setonix_policy.xml /etc/ImageMagick-6/policy.xml
ADD ImageMagick-7_on_setonix_policy.xml /etc/ImageMagick-7/policy.xml
ENV LD_LIBRARY_PATH="/usr/local/lib"

# Metadata labels
LABEL org.opencontainers.image.title="askappy-base" \
      org.opencontainers.image.description="Base image with casacore and scientific computing tools" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="CSIRO" \
      org.opencontainers.image.authors="Wasim Raja <Wasim.Raja@csiro.au>" \
      repo.name="askappy" \
      repo.version="base-casacore-3.6.1" \
      casacore.version="v3.6.1" \
      mpich.version="4.3.1"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 -c "import casacore; print('OK')" || exit 1

CMD ["/bin/bash"]
