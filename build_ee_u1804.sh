#!/bin/bash
EE_BUILD_HOME=`pwd`
EE_BUILD_EE="${EE_BUILD_HOME}/EmptyEpsilon"
EE_BUILD_EE_WIN32="${EE_BUILD_EE}/_build_win32"
EE_BUILD_SP="${EE_BUILD_HOME}/SeriousProton"
EE_BUILD_DATE="$(date +'%Y%m%d')"
EE_BUILD_CMAKE="${EE_BUILD_EE}/cmake"
EE_BUILD_MAKE="/usr/bin/make"

set -e

# Update the system if it hasn't been in the last 12 hours.
if [ -z "$(find /var/cache/apt/pkgcache.bin -mmin -720)" ]
then
  echo "Updating system..."
  sudo apt-get update &&
    sudo apt-get -y upgrade &&
    echo "!   System updated."
fi

# Install tools.
echo "Installing tools..."
sudo apt -y install git build-essential libx11-dev cmake \
  libxrandr-dev mesa-common-dev libglu1-mesa-dev \
  libudev-dev libglew-dev libjpeg-dev libfreetype6-dev \
  libopenal-dev libsndfile1-dev libxcb1-dev \
  libxcb-image0-dev libsfml-dev mingw-w64 cmake gcc g++ zip \
  unzip python3-minimal &&
  echo "!   Tools installed."

## Get SeriousProton and EmptyEpsilon.
if [ ! -d "${EE_BUILD_SP}" ]
then
  echo "Cloning SeriousProton repo to ${EE_BUILD_SP}..."
  git clone https://github.com/daid/SeriousProton.git "${EE_BUILD_SP}"
else
  echo "Fetching and fast-forwarding SeriousProton repo at ${EE_BUILD_SP}..."
  ( cd "${EE_BUILD_SP}" &&
    git fetch --all && git merge --ff-only )
fi
echo "!   SeriousProton source downloaded."

if [ ! -d "${EE_BUILD_EE}" ]
then
  echo "Cloning EmptyEpsilon repo to ${EE_BUILD_EE}..."
  git clone https://github.com/daid/EmptyEpsilon.git "${EE_BUILD_EE}"
else
  echo "Fetching and fast-forwarding EmptyEpsilon repo at ${EE_BUILD_EE}..."
  ( cd "${EE_BUILD_EE}" &&
    git fetch --all && git merge --ff-only )
fi
echo "!   EmptyEpsilon source downloaded."

# Write commit IDs for each repo into a file for reference.
echo "Saving commit IDs..."
for i in "${EE_BUILD_SP}" "${EE_BUILD_EE}"
do
  ( cd "${i}" &&
    echo "-   $(git log --pretty='oneline' -n 1)" )
done

# Build EmptyEpsilon for Windows.
echo "Building EmptyEpsilon for win32..."
( cd "${EE_BUILD_EE}" &&
    mkdir -p "${EE_BUILD_EE_WIN32}" &&
    cd "${EE_BUILD_EE_WIN32}" &&
    cmake .. -DSERIOUS_PROTON_DIR="${EE_BUILD_SP}" \
      -DCMAKE_TOOLCHAIN_FILE="${EE_BUILD_CMAKE}/mingw.toolchain" \
      -DCMAKE_MAKE_PROGRAM="${EE_BUILD_MAKE}" \
      -DCPACK_PACKAGE_VERSION_MAJOR="$(echo ${EE_BUILD_DATE} | cut -c1-4)" \
      -DCPACK_PACKAGE_VERSION_MINOR="$(echo ${EE_BUILD_DATE} | cut -c5-6)" \
      -DCPACK_PACKAGE_VERSION_PATCH="$(echo ${EE_BUILD_DATE} | cut -c7-8)" &&
    make -j 3 package &&
    echo "!   Build complete to ${EE_BUILD_EE}/_build_win32/EmptyEpsilon.zip" )
