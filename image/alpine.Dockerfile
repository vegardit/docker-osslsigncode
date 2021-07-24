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
     # required for curl:
     ca-certificates \
     curl \
     # required for bootstrap:
     autoconf \
     automake \
     libtool \
     # required for configure/make:
     build-base \
     curl-dev \
     openssl-dev && \
  if [ "$OSSLSIGNCODE_VERSION" = "2.1" ]; then \
     apk add --no-cache libgsf-dev; \
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
  if [ "$OSSLSIGNCODE_VERSION" = "2.1" ]; then \
     apk add --no-cache libgsf; \
  fi && \
  #
  /mnt/shared/cmd/alpine-cleanup.sh

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
