# vegardit/docker-osslsigncode <a href="https://github.com/vegardit/docker-osslsigncode/" title="GitHub Repo"><img height="30" src="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/github.svg?sanitize=true"></a>

[![Build Status](https://github.com/vegardit/docker-osslsigncode/workflows/Build/badge.svg "GitHub Actions")](https://github.com/vegardit/docker-osslsigncode/actions?query=workflow%3ABuild)
[![License](https://img.shields.io/github/license/vegardit/docker-osslsigncode.svg?label=license)](#license)
[![Docker Pulls](https://img.shields.io/docker/pulls/vegardit/osslsigncode.svg)](https://hub.docker.com/r/vegardit/osslsigncode)
[![Docker Stars](https://img.shields.io/docker/stars/vegardit/osslsigncode.svg)](https://hub.docker.com/r/vegardit/osslsigncode)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.1%20adopted-ff69b4.svg)](CODE_OF_CONDUCT.md)

1. [What is it?](#what-is-it)
1. [Docker image tagging scheme](#tags)
1. [Usage](#usage)
1. [License](#license)


## <a name="what-is-it"></a>What is it?

Docker image for signing Windows binaries with [Microsoft Authenticode](https://docs.microsoft.com/en-us/windows-hardware/drivers/install/authenticode) using [osslsigncode](https://github.com/mtrojnar/osslsigncode).

It is automatically built **daily** to include the latest OS security fixes.


## <a name="tags"></a>Docker image tagging scheme

|Tag|Description|OS
|-|-|-
|`:latest` <br> `:latest-alpine` | build of the latest available release | Alpine Latest
|`:latest-debian` | build of the latest available release | Debian Stable
|`:develop` <br> `:develop-alpine` | build of the development branch | Alpine Latest
|`:develop-debian` | build of the development branch | Debian Stable
|`:2.x` <br> `:2.x-alpine` | build of the latest minor version of the respective <br> major release, e.g. `2.x` may contain release `2.1` | Alpine Latest
|`:2.x-debian` | build of the latest minor version of the respective <br> major release, e.g. `2.x` may contain release `2.1` | Debian Stable

See all tags at https://hub.docker.com/r/vegardit/osslsigncode/tags


## <a name="usage"></a>Usage

The docker image is configured to use `/work` as work directory.

You can mount the folder with the executables to sign into the `/work` directory and then use relative paths
for `--in` and `--out` parameters of osslsigncode.

For example:
```bash
docker run --rm -v $PWD:/work vegardit/osslsigncode sign \
  -certs mycert.crt -key mykey.der \
  -n 'My Application' -i https://www.mywebsite.com/ \
  -in myapp.exe -out myapp-signed.exe
```


## <a name="license"></a>License

All files in this repository are released under the [Apache License 2.0](LICENSE.txt).

Individual files contain the following tag instead of the full license text:
```
SPDX-License-Identifier: Apache-2.0
```

This enables machine processing of license information based on the SPDX License Identifiers that are available here: https://spdx.org/licenses/.
