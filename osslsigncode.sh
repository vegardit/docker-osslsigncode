#!/bin/sh
#
# Copyright 2021-2022 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-softhsm2-pkcs11-proxy

set -eu

docker run --rm -it \
  -v "$PWD:/work" \
  vegardit/osslsigncode:latest \
  "$@"
