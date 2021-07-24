#syntax=docker/dockerfile:1
#
# Copyright 2021 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-osslsigncode

#############################################################
# build osslsigncode code signing tool
#############################################################
#https://hub.docker.com/_/debian?tab=tags&name=stable-slim
ARG BASE_IMAGE=debian:stable-slim

FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG LC_ALL=C

ARG BASE_LAYER_CACHE_KEY

ARG OSSLSIGNCODE_SOURCE_URL
ARG OSSLSIGNCODE_VERSION


RUN --mount=type=bind,source=.shared,target=/mnt/shared \
  set -eu && \
  /mnt/shared/cmd/debian-install-os-updates.sh && \
  #
  echo "#################################################" && \
  echo "Installing required dev packages ..." && \
  echo "#################################################" && \
  apt-get install --no-install-recommends -y \
     # required for curl:
     ca-certificates \
     curl \
     # required for bootstrap:
     autoconf \
     automake \
     libtool \
     python3-pkgconfig \
     # required for configure/make:
     build-essential \
     libssl-dev \
     libcurl4-openssl-dev \
     && \
  if [ "$OSSLSIGNCODE_VERSION" = "2.1" ]; then \
     apt-get install --no-install-recommends -y libgsf-1-dev; \
  fi

RUN \
  set -eu && \
  echo "#################################################" && \
  echo "Building osslsigncode $OSSLSIGNCODE_VERSION ..." && \
  echo "#################################################" && \
  curl -fsS "$OSSLSIGNCODE_SOURCE_URL" | tar xvz && \
  mv osslsigncode-* osslsigncode && \
  cd osslsigncode && \
  if [ "$OSSLSIGNCODE_VERSION" = "2.1" ]; then \
    ./autogen.sh; \
  else \
    ./bootstrap; \
  fi && \
  ./configure && \
  make && \
  strip osslsigncode && \
  if [ "$OSSLSIGNCODE_VERSION" = "2.1" ]; then \
     # https://github.com/mtrojnar/osslsigncode/issues/102
     (./osslsigncode --version || true); \
  else \
     ./osslsigncode --version; \
  fi


#############################################################
# build final image
#############################################################
FROM ${BASE_IMAGE}

LABEL maintainer="Vegard IT GmbH (vegardit.com)"

USER root

ARG DEBIAN_FRONTEND=noninteractive
ARG LC_ALL=C

ARG BASE_LAYER_CACHE_KEY
ARG INSTALL_SUPPORT_TOOLS=0
ARG OSSLSIGNCODE_VERSION

RUN --mount=type=bind,source=.shared,target=/mnt/shared \
  set -eu && \
  /mnt/shared/cmd/debian-install-os-updates.sh && \
  /mnt/shared/cmd/debian-install-support-tools.sh && \
  #
  echo "#################################################" && \
  echo "Installing required packages..." && \
  echo "#################################################" && \
  apt-get install --no-install-recommends -y \
     ca-certificates \
     libssl1.1 \
     libcurl4 \
     netbase \
     && \
  if [ "$OSSLSIGNCODE_VERSION" = "2.1" ]; then \
     apt-get install --no-install-recommends -y libgsf-bin; \
  fi && \
  #
  /mnt/shared/cmd/debian-cleanup.sh

COPY --from=0 /osslsigncode/osslsigncode /usr/local/bin/osslsigncode

RUN \
  set -eu && \
  mkdir /work && \
  chmod 555 /usr/local/bin/osslsigncode && \
  if [ "$OSSLSIGNCODE_VERSION" = "2.1" ]; then \
     # https://github.com/mtrojnar/osslsigncode/issues/102
     (osslsigncode --version || true); \
  else \
     osslsigncode --version; \
  fi

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
