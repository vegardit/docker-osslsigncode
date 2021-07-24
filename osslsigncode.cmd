@echo off
::
:: Copyright 2021 by Vegard IT GmbH, Germany, https://vegardit.com
:: SPDX-License-Identifier: Apache-2.0
::
:: Author: Sebastian Thomschke, Vegard IT GmbH
::
:: https://github.com/vegardit/docker-softhsm2-pkcs11-proxy

docker run --rm -it  ^
  -v "%cd%:/work" ^
  vegardit/osslsigncode:latest ^
  %*
