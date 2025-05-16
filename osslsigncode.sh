#!/bin/sh
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-osslsigncode

set -eu

docker run --rm -it \
  -v "$PWD:/work" \
  vegardit/osslsigncode:latest \
  "$@"
