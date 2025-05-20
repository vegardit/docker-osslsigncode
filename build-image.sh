#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-osslsigncode

function curl() {
   command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
}

shared_lib="$(dirname "${BASH_SOURCE[0]}")/.shared"
[[ -e $shared_lib ]] || curl "https://raw.githubusercontent.com/vegardit/docker-shared/v1/download.sh?_=$(date +%s)" | bash -s v1 "$shared_lib" || exit 1
# shellcheck disable=SC1091  # Not following: $shared_lib/lib/build-image-init.sh was not specified as input
source "$shared_lib/lib/build-image-init.sh"


#################################################
# specify target image repo/tag
#################################################
image_repo=${DOCKER_IMAGE_REPO:-vegardit/osslsigncode}
base_image_name=${DOCKER_BASE_IMAGE:-alpine:3}
base_image_linux_flavor=${base_image_name%%:*}

app_version=${OSSLSIGNCODE_VERSION:-latest}
case $app_version in \
   latest)
      app_version=$(curl -o /dev/null -w "%{url_effective}\n" https://github.com/mtrojnar/osslsigncode/releases/latest | grep -o '[^/]*$')
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
log INFO "app_version=$app_version"
log INFO "osslsigncode_source_url=$osslsigncode_source_url"


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

tag_args=()
for t in "${tags[@]}"; do
  tag_args+=( --tag "$t" )
done

image_name=${tags[0]}


#################################################
# build the image
#################################################
log INFO "Building docker image [$image_name]..."
if [[ $OSTYPE == cygwin || $OSTYPE == msys ]]; then
   project_root=$(cygpath -w "$project_root")
fi

case $base_image_name in
   alpine:*) dockerfile="alpine.Dockerfile" ;;
   debian:*) dockerfile="debian.Dockerfile" ;;
   *) echo "ERROR: Unsupported base image $base_image_name"; exit 1 ;;
esac

# https://github.com/docker/buildx/#building-multi-platform-images
set -x

docker --version
export DOCKER_BUILD_KIT=1
export DOCKER_CLI_EXPERIMENTAL=1 # prevents "docker: 'buildx' is not a docker command."

# Register QEMU emulators for all architectures so Docker can run and build multi-arch images
docker run --privileged --rm tonistiigi/binfmt --install all

# https://docs.docker.com/build/buildkit/configure/#resource-limiting
echo "
[worker.oci]
  max-parallelism = 3
" | sudo tee /etc/buildkitd.toml

docker buildx version # ensures buildx is enabled
docker buildx create --config /etc/buildkitd.toml --use # prevents: error: multiple platforms feature is currently not supported for docker driver. Please switch to a different driver (eg. "docker buildx create --use")
# shellcheck disable=SC2154  # base_layer_cache_key is referenced but not assigned.
docker buildx build "$project_root" \
   --file "image/$dockerfile" \
   --progress=plain \
   --pull \
   --build-arg "INSTALL_SUPPORT_TOOLS=${INSTALL_SUPPORT_TOOLS:-0}" \
   `# using the current date as value for BASE_LAYER_CACHE_KEY, i.e. the base layer cache (that holds system packages with security updates) will be invalidate once per day` \
   --build-arg BASE_LAYER_CACHE_KEY="$base_layer_cache_key" \
   --build-arg BASE_IMAGE="$base_image_name" \
   --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
   --build-arg GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}" \
   --build-arg GIT_COMMIT_DATE="$(date -d "@$(git log -1 --format='%at')" --utc +'%Y-%m-%d %H:%M:%S UTC')" \
   --build-arg GIT_COMMIT_HASH="$(git rev-parse --short HEAD)" \
   --build-arg GIT_REPO_URL="$(git config --get remote.origin.url)" \
   --build-arg OSSLSIGNCODE_SOURCE_URL="$osslsigncode_source_url" \
   --build-arg OSSLSIGNCODE_VERSION="$app_version" \
   $(if [[ "${ACT:-}" == "true" || "${DOCKER_PUSH:-}" != "true" ]]; then \
      echo -n "--load --output type=docker"; \
   else \
      echo -n "--platform linux/amd64,linux/arm64,linux/arm/v7"; \
   fi) \
   "${tag_args[@]}" \
   $(if [[ "${DOCKER_PUSH:-}" == "true" ]]; then echo -n "--push"; fi) \
   "$@"
docker buildx stop
set +x

if [[ "${DOCKER_PUSH:-}" == "true" ]]; then
   docker image pull $image_name
fi


#################################################
# test image
#################################################
echo
log INFO "Testing docker image [$image_name]..."
(set -x; docker run --rm "$image_name" --version)
echo


#################################################
# perform security audit
#################################################
if [[ ${DOCKER_AUDIT_IMAGE:-1} == 1 ]]; then
   bash "$shared_lib/cmd/audit-image.sh" "$image_name"
fi


#################################################
# push image to ghcr.io
#################################################
if [[ ${DOCKER_PUSH_GHCR:-} == true ]]; then
  for tag in "${tags[@]}"; do
    set -x
    docker run --rm \
      -u "$(id -u):$(id -g)" -e HOME -v "$HOME:$HOME" \
      -v /etc/docker/certs.d:/etc/docker/certs.d:ro \
      ghcr.io/regclient/regctl:latest \
      image copy "$tag" "ghcr.io/$tag"
    set +x
  done
fi
