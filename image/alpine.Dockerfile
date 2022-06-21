#syntax=docker/dockerfile:1
#
# Copyright 2021-2022 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-osslsigncode

#############################################################
# build osslsigncode code signing tool
#############################################################
#https://hub.docker.com/_/alpine?tab=tags&name=latest
ARG BASE_IMAGE=alpine:latest

FROM ${BASE_IMAGE}

ARG BASE_LAYER_CACHE_KEY

ARG OSSLSIGNCODE_SOURCE_URL
ARG OSSLSIGNCODE_VERSION

RUN --mount=type=bind,source=.shared,target=/mnt/shared \
  set -eu && \
  /mnt/shared/cmd/alpine-install-os-updates.sh && \
  #
  echo "#################################################" && \
  echo "Installing required dev packages ..." && \
  echo "#################################################" && \
  apk add --no-cache \
     # required by curl:
     ca-certificates \
     curl \
     #
     build-base \
     curl-dev \
     openssl-dev \
     # required by osslsigncode < 2.3
     autoconf automake libtool \
     # required by osslsigncode >= 2.4
     cmake

RUN \
  set -eu && \
  echo "#################################################" && \
  echo "Building osslsigncode $OSSLSIGNCODE_VERSION ..." && \
  echo "#################################################" && \
  curl -fsS "$OSSLSIGNCODE_SOURCE_URL" | tar xvz && \
  mv osslsigncode-* osslsigncode && \
  cd osslsigncode && \
  mkdir build && \
  if [ -f CMakeLists.txt ]; then \
    # disable CMakeTest which requires faketime command which is not available for alpine
    sed -i '/include(CMakeTest)/d' CMakeLists.txt && \
    #
    cd build && \
    cmake -Denable-strict=ON \
          -Denable-pedantic=ON \
          .. && \
    (cmake --build ./ || ( \
      echo "#################################################" && \
      echo "CMakeOutput.log" && \
      echo "#################################################" && \
      cat /osslsigncode/build/CMakeFiles/CMakeOutput.log && \
      echo "#################################################" && \
      echo "BUILD FAILED." && \
      exit 1 \
    )); \
  else \
    ./bootstrap && \
    ./configure && \
    make && \
    mv osslsigncode build && \
    cd build; \
  fi && \
  strip osslsigncode && \
  ./osslsigncode --version


#############################################################
# build final image
#############################################################
FROM ${BASE_IMAGE}

LABEL maintainer="Vegard IT GmbH (vegardit.com)"

USER root

ARG BASE_LAYER_CACHE_KEY
ARG OSSLSIGNCODE_VERSION

RUN --mount=type=bind,source=.shared,target=/mnt/shared \
  set -eu && \
  /mnt/shared/cmd/alpine-install-os-updates.sh && \
  #
  echo "#################################################" && \
  echo "Installing required packages..." && \
  echo "#################################################" && \
  apk add --no-cache \
     ca-certificates \
     libssl1.1 \
     libcurl \
     && \
  #
  /mnt/shared/cmd/alpine-cleanup.sh

COPY --from=0 /osslsigncode/build/osslsigncode /usr/local/bin/osslsigncode

RUN \
  set -eu && \
  mkdir /work && \
  chmod 555 /usr/local/bin/osslsigncode && \
  osslsigncode --version

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
