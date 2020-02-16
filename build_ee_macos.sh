#!/bin/bash
EE_BUILD_HOME=`pwd`
EE_BUILD_EE_PATH="${EE_BUILD_HOME}/EmptyEpsilon"
EE_BUILD_SP_PATH="${EE_BUILD_HOME}/SeriousProton"
EE_BUILD_APP_PATH="${EE_BUILD_HOME}/EmptyEpsilon.app"
EE_BUILD_DATE="$(date +'%Y%m%d')"
EE_BUILD_CMAKE="${EE_BUILD_EE_PATH}/cmake"

## Install XCode.
xcode-select --install

## Install cmake and SFML via Homebrew.
brew install cmake sfml

## Clone SeriousProton and EmptyEpsilon.
## Get SeriousProton and EmptyEpsilon.
if [ ! -d "${EE_BUILD_SP_PATH}" ]; then
  echo "-   Cloning SeriousProton repo to ${EE_BUILD_SP_PATH}..."
  git clone https://github.com/daid/SeriousProton.git "${EE_BUILD_SP_PATH}"
else
  echo "-   Fetching and merging SeriousProton repo at ${EE_BUILD_SP_PATH}..."
  ( cd "${EE_BUILD_SP_PATH}";
    git fetch --all && git merge --ff-only; )
fi
echo

if [ ! -d "${EE_BUILD_EE_PATH}" ]; then
  echo "-   Cloning EmptyEpsilon repo to ${EE_BUILD_EE_PATH}..."
  git clone https://github.com/daid/EmptyEpsilon.git "${EE_BUILD_EE_PATH}"
else
  echo "-   Fetching and merging EmptyEpsilon repo at ${EE_BUILD_EE_PATH}..."
  ( cd "${EE_BUILD_EE_PATH}";
    git fetch --all && git merge --ff-only; )
fi
echo

## Build for macOS.
( cd "${EE_BUILD_EE_PATH}" &&
  cmake CMakeLists.txt -DSERIOUS_PROTON_DIR=${EE_BUILD_SP_PATH} \
    -DCPACK_PACKAGE_VERSION_MAJOR=2020 -DCPACK_PACKAGE_VERSION_MINOR=01 \
    -DCPACK_PACKAGE_VERSION_PATCH=15 &&
  make &&
  make install )
