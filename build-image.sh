#!/usr/bin/env bash
#
# Copyright 2021-2022 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-osslsigncode

shared_lib="$(dirname $0)/.shared"
[ -e "$shared_lib" ] || curl -sSf https://raw.githubusercontent.com/vegardit/docker-shared/v1/download.sh?_=$(date +%s) | bash -s v1 "$shared_lib" || exit 1
source "$shared_lib/lib/build-image-init.sh"


#################################################
# specify target docker registry/repo
#################################################
docker_registry=${DOCKER_REGISTRY:-docker.io}
image_repo=${DOCKER_IMAGE_REPO:-vegardit/osslsigncode}
base_image_name=${DOCKER_BASE_IMAGE:-alpine:3}
base_image_linux_flavor=${base_image_name%%:*}

app_version=${OSSLSIGNCODE_VERSION:-latest}
case $app_version in \
   latest)
      app_version=$(curl -sSfL -o /dev/null -w "%{url_effective}\n" https://github.com/mtrojnar/osslsigncode/releases/latest | grep -o '[^/]*$')
      osslsigncode_source_url=https://codeload.github.com/mtrojnar/osslsigncode/tar.gz/refs/tags/$app_version
      app_version_is_latest=1
     ;;
   develop)
      osslsigncode_source_url=https://codeload.github.com/mtrojnar/osslsigncode/tar.gz/refs/heads/master
     ;;
   *)
      osslsigncode_source_url=https://codeload.github.com/mtrojnar/osslsigncode/tar.gz/refs/tags/$app_version
     ;;
esac
echo "app_version=$app_version"
echo "osslsigncode_source_url=$osslsigncode_source_url"


#################################################
# calculate tags
#################################################
declare -a tags=()

if [[ $app_version == develop ]]; then
   tags+=("$image_repo:develop-$base_image_linux_flavor") # :develop-alpine
   if [[ $base_image_linux_flavor == alpine ]]; then
      tags+=("$image_repo:develop") # :develop
   fi
else
   if [[ $app_version =~ ^[0-9]+\..*$ ]]; then
      tags+=("$image_repo:${app_version%%.*}.x-$base_image_linux_flavor") # :2.x-alpine
      if [[ $base_image_linux_flavor == alpine ]]; then
         tags+=("$image_repo:${app_version%%.*}.x-$base_image_linux_flavor") # :2.x
      fi
   fi

   if [[ ${app_version_is_latest:-} == 1 ]]; then
      tags+=("$image_repo:latest-$base_image_linux_flavor") # :latest-alpine
      if [[ $base_image_linux_flavor == alpine ]]; then
         tags+=("$image_repo:latest") # :latest
      fi
   fi
fi

image_name=${tags[0]}


#################################################
# build the image
#################################################
echo "Building docker image [$image_name]..."
if [[ $OSTYPE == "cygwin" || $OSTYPE == "msys" ]]; then
   project_root=$(cygpath -w "$project_root")
fi

case $base_image_name in
  alpine:*) dockerfile="alpine.Dockerfile" ;;
  debian:*) dockerfile="debian.Dockerfile" ;;
  *) echo "ERROR: Unsupported base image $base_image_name"; exit 1 ;;
esac

docker pull $base_image_name

# https://github.com/docker/buildx/#building-multi-platform-images
docker run --privileged --rm tonistiigi/binfmt --install all
export DOCKER_CLI_EXPERIMENTAL=enabled # prevents "docker: 'buildx' is not a docker command."
docker buildx create --use # prevents: error: multiple platforms feature is currently not supported for docker driver. Please switch to a different driver (eg. "docker buildx create --use")
docker buildx build "$project_root" \
   --file "image/$dockerfile" \
   --progress=plain \
   --build-arg INSTALL_SUPPORT_TOOLS=${INSTALL_SUPPORT_TOOLS:-0} \
   `# using the current date as value for BASE_LAYER_CACHE_KEY, i.e. the base layer cache (that holds system packages with security updates) will be invalidate once per day` \
   --build-arg BASE_LAYER_CACHE_KEY=$base_layer_cache_key \
   --build-arg BASE_IMAGE=$base_image_name \
   --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
   --build-arg GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}" \
   --build-arg GIT_COMMIT_DATE="$(date -d @$(git log -1 --format='%at') --utc +'%Y-%m-%d %H:%M:%S UTC')" \
   --build-arg GIT_COMMIT_HASH="$(git rev-parse --short HEAD)" \
   --build-arg GIT_REPO_URL="$(git config --get remote.origin.url)" \
   --build-arg OSSLSIGNCODE_SOURCE_URL="$osslsigncode_source_url" \
   --build-arg OSSLSIGNCODE_VERSION="$app_version" \
   --platform linux/amd64,linux/arm64 \
   -t $image_name \
   $(for tag in ${tags[@]}; do echo -n " -t $tag "; done) \
   $(if [[ "${DOCKER_PUSH:-0}" == "1" ]]; then echo -n "--push"; fi) \
   "$@"
docker buildx stop
docker image pull $image_name


#################################################
# perform security audit
#################################################
bash "$shared_lib/cmd/audit-image.sh" $image_name
