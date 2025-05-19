#syntax=docker/dockerfile:1
# see https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md
# see https://docs.docker.com/engine/reference/builder/#syntax
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-osslsigncode

#############################################################
# build osslsigncode code signing tool
#############################################################
# https://hub.docker.com/_/alpine/tags?name=latest
# https://github.com/alpinelinux/docker-alpine/blob/master/Dockerfile
ARG BASE_IMAGE=alpine:latest

# https://github.com/hadolint/hadolint/wiki/DL3006 Always tag the version of an image explicitly
# hadolint ignore=DL3006
FROM ${BASE_IMAGE} AS builder

ARG BASE_LAYER_CACHE_KEY

ARG OSSLSIGNCODE_SOURCE_URL
ARG OSSLSIGNCODE_VERSION

SHELL ["/bin/ash", "-euo", "pipefail", "-c"]

# https://github.com/hadolint/hadolint/wiki/DL3018 Pin versions
# hadolint ignore=DL3018
RUN --mount=type=bind,source=.shared,target=/mnt/shared <<EOF
  #!/bin/ash
  /mnt/shared/cmd/alpine-install-os-updates.sh

  echo "#################################################"
  echo "Installing required dev packages..."
  echo "#################################################"
  apk add --no-cache \
     `# required by curl:` \
     ca-certificates \
     curl \
     \
     build-base \
     curl-dev \
     openssl-dev \
     `# required by osslsigncode < 2.4:` \
     autoconf automake libtool \
     `# required by osslsigncode >= 2.4:` \
     cmake

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
    cmake -Denable-strict=ON \
          -Denable-pedantic=ON \
          ..
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
FROM ${BASE_IMAGE}

LABEL maintainer="Vegard IT GmbH (vegardit.com)"

# https://github.com/hadolint/hadolint/wiki/DL3002 Last USER should not be root
# hadolint ignore=DL3002
USER root

ARG BASE_LAYER_CACHE_KEY
ARG OSSLSIGNCODE_VERSION

SHELL ["/bin/ash", "-euo", "pipefail", "-c"]

# https://github.com/hadolint/hadolint/wiki/DL3018 Pin versions
# hadolint ignore=DL3018
RUN --mount=type=bind,source=.shared,target=/mnt/shared <<EOF
  /mnt/shared/cmd/alpine-install-os-updates.sh

  echo "#################################################"
  echo "Installing required packages..."
  echo "#################################################"
  apk add --no-cache \
    ca-certificates \
    libssl3 \
    libcurl

  /mnt/shared/cmd/alpine-cleanup.sh

EOF

COPY --from=builder /osslsigncode/build/osslsigncode /usr/local/bin/osslsigncode

RUN <<EOF
  set -eu
  mkdir /work
  chmod 555 /usr/local/bin/osslsigncode
  osslsigncode --version

EOF

ARG BUILD_DATE
ARG GIT_BRANCH
ARG GIT_COMMIT_HASH
ARG GIT_COMMIT_DATE
ARG GIT_REPO_URL

LABEL \
  org.label-schema.schema-version="1.0" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.vcs-ref=$GIT_COMMIT_HASH \
  org.label-schema.vcs-url=$GIT_REPO_URL

WORKDIR /work

ENTRYPOINT ["/usr/local/bin/osslsigncode"]
