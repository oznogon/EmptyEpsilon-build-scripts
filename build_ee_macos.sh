#!/bin/bash
EE_BUILD_HOME=`pwd`
EE_BUILD_EE_PATH="${EE_BUILD_HOME}/EmptyEpsilon"
EE_BUILD_SP_PATH="${EE_BUILD_HOME}/SeriousProton"
EE_BUILD_EE_APP_PATH="${EE_BUILD_HOME}/EmptyEpsilon.app"
EE_BUILD_DATE="$(date +'%Y%m%d')"
EE_BUILD_CMAKE="${EE_BUILD_EE_PATH}/cmake"

# Install XCode.
xcode-select --install

# Install cmake and SFML via Homebrew.
brew install cmake sfml

# Clone SeriousProton and EmptyEpsilon.
if [ ! -d "${EE_BUILD_SP_PATH}" ]
then
  echo "Cloning SeriousProton repo to ${EE_BUILD_SP_PATH}..."
  git clone https://github.com/daid/SeriousProton.git "${EE_BUILD_SP_PATH}" &&
  echo "!   SeriousProton source downloaded."
else
  echo "Fetching and fast-forwarding SeriousProton repo at ${EE_BUILD_SP_PATH}..."
  ( cd "${EE_BUILD_SP_PATH}"
    git fetch --all && git merge --ff-only &&
    echo "!   SeriousProton source updated." )
fi
echo

if [ ! -d "${EE_BUILD_EE_PATH}" ]
then
  echo "Cloning EmptyEpsilon repo to ${EE_BUILD_EE_PATH}..."
  git clone https://github.com/daid/EmptyEpsilon.git "${EE_BUILD_EE_PATH}"
else
  echo "Fetching and fast-forwarding EmptyEpsilon repo at ${EE_BUILD_EE_PATH}..."
  ( cd "${EE_BUILD_EE_PATH}"
    git fetch --all && git merge --ff-only &&
    echo "!   EmptyEpsilon source updated.")
fi
echo

# Build for macOS.
( mkdir -p "${EE_BUILD_EE_PATH}/_build_macos" &&
  cd "${EE_BUILD_EE_PATH}/_build_macos" &&
  cmake .. \
    -DSERIOUS_PROTON_DIR="${EE_BUILD_SP_PATH}" \
    -DCPACK_PACKAGE_VERSION_MAJOR="${EE_BUILD_DATE:0:4}" \
    -DCPACK_PACKAGE_VERSION_MINOR="${EE_BUILD_DATE:4:2}" \
    -DCPACK_PACKAGE_VERSION_PATCH="${EE_BUILD_DATE:6:2}" &&
  make &&
  make install &&
  echo "!   macOS build complete to ${EE_BUILD_EE_APP_PATH}" )
