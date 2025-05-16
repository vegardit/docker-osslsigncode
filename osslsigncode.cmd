@echo off
::
:: SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
:: SPDX-FileContributor: Sebastian Thomschke
:: SPDX-License-Identifier: Apache-2.0
:: SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-osslsigncode

docker run --rm -it  ^
  -v "%cd%:/work" ^
  vegardit/osslsigncode:latest ^
  %*
