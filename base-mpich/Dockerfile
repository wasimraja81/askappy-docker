# syntax=docker/dockerfile:1

#####################################################################
# base-mpich Docker Image - Ubuntu 24.04 with MPICH only
# This image is used as a base for casacore and other scientific stacks
#####################################################################

ARG UBUNTU_VERSION=24.04
ARG TARGETPLATFORM=linux/amd64

FROM --platform=${TARGETPLATFORM} ubuntu:${UBUNTU_VERSION} as builder

ARG TARGETPLATFORM
ARG DEBIAN_FRONTEND=noninteractive

# Build-time metadata
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

ENV TZ=Etc/UTC

RUN apt-get update -qq \
    && apt-get install -yq tzdata \
    && ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && apt-get -y --no-install-recommends install \
        git wget build-essential cmake gfortran g++ \
        ca-certificates libc6 libssl-dev libffi-dev libncurses-dev libreadline-dev \
        libhwloc-dev libibverbs-dev libopenmpi-dev \
        python3-dev python3-pip python3-pyparsing python3-numpy python3-setuptools \
        libblas-dev liblapacke-dev libcfitsio-dev libpthread-stubs0-dev libgsl-dev wcslib-dev libfftw3-dev \
        imagemagick libmagickcore-dev libmagickwand-dev libmagic-dev \
        libbz2-dev libclang-dev libboost-python-dev libx11-dev \
        fuse libfuse2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG BUILD_DIR=/_build
ARG INSTALL_DIR=/_install
RUN mkdir -p ${INSTALL_DIR} ${BUILD_DIR}

# Install python3.10 and pip3
RUN apt-get update && \
    apt-get install -y software-properties-common gfortran && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.10-dev python3.10 python3.10-distutils python3-pip

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
RUN ln -sf /usr/bin/python3 /usr/local/bin/python
RUN python3 -m pip install --ignore-installed 'pip<22' 'setuptools<59' wheel --break-system-packages
RUN python3 -m pip install --ignore-installed 'numpy<1.24'

# Build MPICH only
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

# Metadata labels
LABEL org.opencontainers.image.title="base-mpich" \
      org.opencontainers.image.description="Base image with MPICH only" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="CSIRO" \
      org.opencontainers.image.authors="Wasim Raja <Wasim.Raja@csiro.au>" \
      mpich.version="4.3.1"

CMD ["/bin/bash"]
