# syntax=docker/dockerfile:1

#####################################################################
# base-casacore Docker Image - Ubuntu 24.04 with MPICH and Casacore
# This image is used as a base for askappy-base and other stacks
#####################################################################

ARG BASE_MPICH_VERSION=base-mpich-latest
ARG TARGETPLATFORM=linux/amd64
FROM --platform=${TARGETPLATFORM} wasimraja81/base-mpich:${BASE_MPICH_VERSION} as mpich-base

ARG TARGETPLATFORM
ARG DEBIAN_FRONTEND=noninteractive

# Build-time metadata
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

ARG BUILD_DIR=/_build
ARG MEASURES_DATA="/_build/measures_data"
ARG INSTALL_DIR=/_install


# Build Boost.Python for Python 3.10 from source
RUN apt-get update && \
    apt-get install -y build-essential g++ python3.10-dev wget && \
    cd /tmp && \
    wget -O boost_1_83_0.tar.gz https://sourceforge.net/projects/boost/files/boost/1.83.0/boost_1_83_0.tar.gz/download && \
    tar xzf boost_1_83_0.tar.gz && \
    cd boost_1_83_0 && \
    ./bootstrap.sh --with-python=python3.10 && \
    ./b2 --with-python -j$(nproc) && \
    ./b2 --with-python install && \
    cd / && rm -rf /tmp/boost_1_83_0* /tmp/boost_1_83_0.tar.gz

RUN mkdir -p ${INSTALL_DIR} ${BUILD_DIR} ${MEASURES_DATA}

# Download measures data
RUN cd ${MEASURES_DATA} \
    && wget -q ftp://ftp.astron.nl/outgoing/Measures/WSRT_Measures.ztar \
    && tar xf *.ztar \
    && rm *.ztar

# Build casacore
ARG CASACORE_VERSION=v3.7.1
ARG CPU_CORE_COUNT=4
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

# Build python-casacore
# Minimal environment variables to guide python-casacore's CMake
ENV CMAKE_PREFIX_PATH=/usr/local:/usr/lib/x86_64-linux-gnu

# Install Python packages (including python-casacore) 
RUN apt-get update && apt-get install -y ninja-build
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-deps --no-cache-dir -r /tmp/requirements.txt \
    && pip3 install --default-timeout=120 --no-binary python-casacore python-casacore \
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
LABEL org.opencontainers.image.title="base-casacore" \
      org.opencontainers.image.description="Base image with MPICH and Casacore" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="CSIRO" \
      org.opencontainers.image.authors="Wasim Raja <Wasim.Raja@csiro.au>" \
      casacore.version="v3.7.1" \
      mpich.base.image="wasimraja81/base-mpich:latest"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 -c "import casacore; print('OK')" || exit 1

CMD ["/bin/bash"]
