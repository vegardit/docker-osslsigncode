#syntax=docker/dockerfile:1
# see https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md
# see https://docs.docker.com/engine/reference/builder/#syntax
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-osslsigncode

# https://hub.docker.com/_/debian/tags?name=stable-slim
ARG BASE_IMAGE=debian:stable-slim

#############################################################
# build osslsigncode code signing tool
#############################################################

# https://github.com/hadolint/hadolint/wiki/DL3006 Always tag the version of an image explicitly
# hadolint ignore=DL3006
FROM ${BASE_IMAGE} AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG LC_ALL=C

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ARG OSSLSIGNCODE_SOURCE_URL
ARG OSSLSIGNCODE_VERSION

ARG BASE_LAYER_CACHE_KEY

# https://github.com/hadolint/hadolint/wiki/DL3008 Pin versions
# hadolint ignore=DL3008
RUN --mount=type=bind,source=.shared,target=/mnt/shared <<EOF
  /mnt/shared/cmd/debian-install-os-updates.sh

  echo "#################################################"
  echo "Installing required dev packages..."
  echo "#################################################"
  apt-get install --no-install-recommends -y \
    `# required by curl:` \
    ca-certificates \
    curl \
    \
    build-essential \
    libssl-dev \
    libcurl4-openssl-dev \
    zlib1g-dev \
    `# required by osslsigncode < 2.4:` \
    autoconf \
    automake \
    libtool \
    python3-pkgconfig \
    `# required by osslsigncode >= 2.4:` \
    cmake \
    `# required by CMakeTest:` \
    faketime \
    python3

EOF

# https://github.com/hadolint/hadolint/wiki/DL3003 Use WORKDIR to switch to a directory
# hadolint ignore=DL3003
RUN <<EOF
  echo "#################################################"
  echo "Building osslsigncode $OSSLSIGNCODE_VERSION ..."
  echo "#################################################"
  curl -fsS "$OSSLSIGNCODE_SOURCE_URL" | tar xvz
  mv osslsigncode-* osslsigncode
  cd osslsigncode || exit 1
  mkdir build
  if [ -f CMakeLists.txt ]; then
    # disable CMakeTest which requires faketime command which is not available for alpine
    sed -i '/include(CMakeTest)/d' CMakeLists.txt

    cd build || exit 1
    cmake -Denable-strict=ON -Denable-pedantic=ON ..
    (cmake --build ./ || (
      echo "#################################################"
      echo "CMakeOutput.log:"
      echo "#################################################"
      cat /osslsigncode/build/CMakeFiles/CMakeOutput.log
      echo "#################################################"
      echo "BUILD FAILED."
      exit 1
    ));
  else
    ./bootstrap
    ./configure
    make
    mv osslsigncode build
    cd build || exit 1
  fi
  strip osslsigncode
  ./osslsigncode --version

EOF


#############################################################
# build final image
#############################################################

# https://github.com/hadolint/hadolint/wiki/DL3006 Always tag the version of an image explicitly
# hadolint ignore=DL3006
FROM ${BASE_IMAGE} as final

ARG DEBIAN_FRONTEND=noninteractive
ARG LC_ALL=C

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ARG INSTALL_SUPPORT_TOOLS=0
ARG BASE_LAYER_CACHE_KEY

# https://github.com/hadolint/hadolint/wiki/DL3008 Pin versions
# hadolint ignore=DL3008
RUN --mount=type=bind,source=.shared,target=/mnt/shared <<EOF
  /mnt/shared/cmd/debian-install-os-updates.sh
  /mnt/shared/cmd/debian-install-support-tools.sh

  echo "#################################################"
  echo "Installing required packages..."
  echo "#################################################"
  apt-get install --no-install-recommends -y \
    ca-certificates \
    libssl3t64 \
    libcurl4t64 \
    netbase

  /mnt/shared/cmd/debian-cleanup.sh

EOF

COPY --from=builder /osslsigncode/build/osslsigncode /usr/local/bin/osslsigncode

RUN <<EOF
  mkdir /work
  chmod 555 /usr/local/bin/osslsigncode
  osslsigncode --version

EOF

ARG OCI_authors
ARG OCI_title
ARG OCI_description
ARG OCI_source
ARG OCI_revision
ARG OCI_version
ARG OCI_created

# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL \
  org.opencontainers.image.title="$OCI_title" \
  org.opencontainers.image.description="$OCI_description" \
  org.opencontainers.image.source="$OCI_source" \
  org.opencontainers.image.revision="$OCI_revision" \
  org.opencontainers.image.version="$OCI_version" \
  org.opencontainers.image.created="$OCI_created"

LABEL maintainer="$OCI_authors"

WORKDIR /work

ENTRYPOINT ["/usr/local/bin/osslsigncode"]
