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

# Set up Python environment
RUN update-alternatives --remove python /usr/bin/python2 || true \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 10

#####################################################################
# Build MPICH from source
#####################################################################
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
# Build Casacore from source
#####################################################################
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
# Stage 2: Runtime image
#####################################################################
FROM --platform=${TARGETPLATFORM} ubuntu:${UBUNTU_VERSION} as runtime

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install only runtime dependencies with explicit BLAS library paths for CMake
RUN apt-get update -qq \
    && apt-get install -yq tzdata \
    && ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && apt-get -y --no-install-recommends install \
        # Essential tools
        vim \
        vim-gtk3 \
        vim-gui-common \
        openssh-server \
        ca-certificates \
        # Minimal development tools for Python packages that need compilation
        build-essential \
        python3-dev \
        libssl-dev \
        libbz2-dev \
        zlib1g-dev \
        libncurses-dev \
        libreadline-dev \
        libffi-dev \
        libexpat1-dev \
        # Scientific computing development libraries needed for python-casacore
        wcslib-dev \
        libcfitsio-dev \
        libblas-dev \
        liblapack-dev \
        libopenblas-dev \
        libopenblas-base \
        libatlas-base-dev \
        libatlas3-base \
        libblas3 \
        liblapack3 \
        gfortran \
        pkg-config \
        # Runtime libraries for compiled dependencies
        libgfortran5 \
        libc6 \
        libhwloc15 \
        libibverbs1 \
        libopenmpi3 \
        imagemagick \
        libmagickcore-6.q16-7t64 \
        libmagickwand-6.q16-7t64 \
        libmagic1 \
        fuse \
        libfuse2 \
        libssl3 \
        libffi8 \
        libncurses6 \
        libreadline8 \
        libblas3 \
        liblapack3 \
        libcfitsio10 \
        libgsl27 \
        libfftw3-double3 \
        libbz2-1.0 \
        libboost-python1.83.0 \
        # Python runtime
        python3 \
        python3-pip \
        python3-pyparsing \
        python3-numpy \
        python3-pyqt5 \
        # X11 runtime (if needed)
        xauth \
        xorg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Copy built libraries and binaries from builder stage
COPY --from=builder /usr/local/ /usr/local/
COPY --from=builder /_build/measures_data /_build/measures_data

# Set up Python environment
RUN update-alternatives --remove python /usr/bin/python2 || true \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 10

# Install Python packages
# Set environment variables to help CMake find BLAS libraries
ENV BLA_VENDOR=OpenBLAS
ENV CMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu:/usr/local
ENV PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig
ENV BLAS_LIBRARIES=/usr/lib/x86_64-linux-gnu/libopenblas.so
ENV LAPACK_LIBRARIES=/usr/lib/x86_64-linux-gnu/liblapack.so
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --break-system-packages --no-cache-dir -r /tmp/requirements.txt \
    && pip3 install --break-system-packages --default-timeout=120 --no-binary python-casacore python-casacore \
    && rm /tmp/requirements.txt

# Create non-root user for security
ARG USERNAME=askappy
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && mkdir -p /home/$USERNAME/.casa \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME

# Set up casa configuration
COPY config.py /home/$USERNAME/.casa/
RUN chown $USERNAME:$USERNAME /home/$USERNAME/.casa/config.py

# Configure ImageMagick policy
COPY ImageMagick-7_on_setonix_policy.xml /etc/ImageMagick-6/policy.xml

# Set environment variables
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PYTHONPATH="/usr/local/lib/python3.12/site-packages:${PYTHONPATH}"
ENV PATH="/usr/local/bin:${PATH}"

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

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 -c "import casacore; print('OK')" || exit 1

CMD ["/bin/bash"]
