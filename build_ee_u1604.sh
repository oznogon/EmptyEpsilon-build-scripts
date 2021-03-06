#!/bin/bash
SFML_ROOT="/usr/local/lib"
SFML_INCLUDE_DIR="/usr/local/include/SFML"
EE_BUILD_HOME=`pwd`
EE_BUILD_SFML="${EE_BUILD_HOME}/SFML"
EE_BUILD_EE="${EE_BUILD_HOME}/EmptyEpsilon"
EE_BUILD_EE_WIN32="${EE_BUILD_EE}/_build_win32"
EE_BUILD_EE_LINUX="${EE_BUILD_EE}/_build_linux"
EE_BUILD_EE_ANDROID="${EE_BUILD_EE}/_build_android"
EE_BUILD_EE_ANDROID_KEYSTORE="$HOME/.keystore"
EE_BUILD_EE_ANDROID_KEYSTORE_ALIAS="Android"
EE_BUILD_EE_ANDROID_KEYSTORE_PASSWORD="password"
EE_BUILD_SP="${EE_BUILD_HOME}/SeriousProton"
EE_BUILD_DATE="$(date +'%Y%m%d')"
EE_BUILD_EE_CMAKE="${EE_BUILD_EE}/cmake"
EE_BUILD_CMAKE_VERSION="3.16.4"
EE_BUILD_CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${EE_BUILD_CMAKE_VERSION}/cmake-${EE_BUILD_CMAKE_VERSION}-Linux-x86_64.tar.gz"
EE_BUILD_CMAKE_BIN="${EE_BUILD_HOME}/cmake-${EE_BUILD_CMAKE_VERSION}-Linux-x86_64/bin/cmake"
EE_BUILD_MAKE_BIN="/usr/bin/make"

set -e

# Require an argument
if [ "$#" == "0" ]
then
  echo "X   No targets provided as arguments. Valid arguments: win32 linux android"
  exit 1
fi

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
sudo apt -y install git build-essential libx11-dev \
  libxrandr-dev mesa-common-dev libglu1-mesa-dev \
  libudev-dev libglew-dev libjpeg-dev libfreetype6-dev \
  libopenal-dev libsndfile1-dev libxcb1-dev \
  libxcb-image0-dev mingw-w64 cmake gcc g++ zip \
  unzip p7zip-full python3-minimal openjdk-8-jdk libxcursor-dev && # cmake libsfml-dev
  echo "!   Tools installed."

# Get CMake.
if [ ! -f "${EE_BUILD_CMAKE_BIN}" ]
then
  echo "Downloading CMake ${EE_BUILD_CMAKE_VERSION}..."
  wget "${EE_BUILD_CMAKE_URL}" &&
    tar zxf cmake*.tar.gz &&
    echo "!   CMake downloaded."
else
  echo "!   CMake already present."
fi

# Get SFML.
if [ ! -d "${EE_BUILD_SFML}" ]
then
  echo "Cloning SFML repo to ${EE_BUILD_SFML}..."
  git clone https://github.com/SFML/SFML.git "${EE_BUILD_SFML}" &&
  echo "!   SFML source cloned."
else
  echo "Fetching and fast-forwarding SFML repo at ${EE_BUILD_SFML}..."
  ( cd "${EE_BUILD_SFML}" &&
    git fetch --all && git merge --ff-only &&
    echo "!   SFML source is up to date." )
fi

# Get SeriousProton and EmptyEpsilon.
if [ ! -d "${EE_BUILD_SP}" ]
then
  echo "Cloning SeriousProton repo to ${EE_BUILD_SP}..."
  git clone https://github.com/daid/SeriousProton.git "${EE_BUILD_SP}" &&
  echo "!   SeriousProton source cloned."
else
  echo "Fetching and fast-forwarding SeriousProton repo at ${EE_BUILD_SP}..."
  ( cd "${EE_BUILD_SP}" &&
    git fetch --all && git merge --ff-only &&
    echo "!   SeriousProton source is up to date." )
fi

if [ ! -d "${EE_BUILD_EE}" ]
then
  echo "Cloning EmptyEpsilon repo to ${EE_BUILD_EE}..."
  git clone https://github.com/daid/EmptyEpsilon.git "${EE_BUILD_EE}" &&
  echo "!   EmptyEpsilon source cloned."
else
  echo "Fetching and fast-forwarding EmptyEpsilon repo at ${EE_BUILD_EE}..."
  ( cd "${EE_BUILD_EE}" &&
    git fetch --all && git merge --ff-only &&
    echo "!   EmptyEpsilon source is up to date." )
fi

# Write commit IDs for each repo into a file for reference.
echo "Saving commit IDs..."
for i in "${EE_BUILD_SP}" "${EE_BUILD_EE}" "${EE_BUILD_SFML}"
do
  ( cd "${i}" &&
    echo "-   $(git log --pretty='oneline' -n 1)" )
done

# Build SFML.
echo "Building SFML..."
( cd "${EE_BUILD_SFML}" &&
  mkdir -p "${EE_BUILD_SFML}/_build" &&
  cd "${EE_BUILD_SFML}/_build" &&
  cmake "${EE_BUILD_SFML}" &&
  make &&
  echo "!   SFML built." &&
  sudo make install &&
  echo "!   SFML installed." &&
  sudo ldconfig &&
  echo "!   SFML libraries linked." )

for arg in "$@"
do
  if [ "$arg" == "win32" ]
  then
    # Build EmptyEpsilon for Windows.
    echo "Building EmptyEpsilon for win32..."
    ( cd "${EE_BUILD_EE}" &&
      mkdir -p "${EE_BUILD_EE_WIN32}" &&
      cd "${EE_BUILD_EE_WIN32}" &&
      ${EE_BUILD_CMAKE_BIN} .. \
        -DSERIOUS_PROTON_DIR="${EE_BUILD_SP}" \
        -DCMAKE_TOOLCHAIN_FILE="${EE_BUILD_EE_CMAKE}/mingw.toolchain" \
        -DCMAKE_MAKE_PROGRAM="${EE_BUILD_MAKE_BIN}" \
        -DCPACK_PACKAGE_VERSION_MAJOR="${EE_BUILD_DATE:0:4}" \
        -DCPACK_PACKAGE_VERSION_MINOR="${EE_BUILD_DATE:4:2}" \
        -DCPACK_PACKAGE_VERSION_PATCH="${EE_BUILD_DATE:6:2}" &&
      make -j 3 package &&
      echo "!   win32 build complete to ${EE_BUILD_EE_WIN32}/EmptyEpsilon.zip" )
  elif [ "$arg" == "linux" ]
  then
    # Build EmptyEpsilon for Debian.
    echo "Building EmptyEpsilon for Debian..."
    ( cd "${EE_BUILD_EE}" &&
      mkdir -p "${EE_BUILD_EE_LINUX}" &&
      cd "${EE_BUILD_EE_LINUX}" &&
      ${EE_BUILD_CMAKE_BIN} .. \
        -DSERIOUS_PROTON_DIR="${EE_BUILD_SP}" \
        -DCMAKE_MAKE_PROGRAM="${EE_BUILD_MAKE_BIN}" \
        -DCPACK_PACKAGE_VERSION_MAJOR="${EE_BUILD_DATE:0:4}" \
        -DCPACK_PACKAGE_VERSION_MINOR="${EE_BUILD_DATE:4:2}" \
        -DCPACK_PACKAGE_VERSION_PATCH="${EE_BUILD_DATE:6:2}" &&
      make &&
      cpack \
        -G DEB \
        -D CPACK_PACKAGE_CONTACT=https://github.com/daid/ \
        -R "${EE_BUILD_DATE:0:4}.${EE_BUILD_DATE:4:2}.${EE_BUILD_DATE:6:2}" &&
      echo "!   Debian build complete to ${EE_BUILD_EE_LINUX}/EmptyEpsilon.deb" )
  elif [ "$arg" == "android" ]
  then
    # Build EmptyEpsilon for Android.
    echo "Building EmptyEpsilon for Android..."
    if [ ! -f "${EE_BUILD_EE_ANDROID_KEYSTORE}" ]
    then
      echo "-   Generating keystore..."
      keytool -genkey \
        -noprompt \
        -alias "${EE_BUILD_EE_ANDROID_KEYSTORE_ALIAS}" \
        -dname "CN=daid.github.io, OU=EmptyEpsilon, O=EmptyEpsilon, L=None, ST=None, C=None" \
        -keystore "${EE_BUILD_EE_ANDROID_KEYSTORE}" \
        -storepass "${EE_BUILD_EE_ANDROID_KEYSTORE_PASSWORD}" \
        -keypass "${EE_BUILD_EE_ANDROID_KEYSTORE_PASSWORD}" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 &&
      echo "!   Keystore generated to ${EE_BUILD_EE_ANDROID_KEYSTORE}."
    fi

    ( cd "${EE_BUILD_EE}" &&
      mkdir -p "${EE_BUILD_EE_ANDROID}" &&
      cd "${EE_BUILD_EE_ANDROID}" &&
      ${EE_BUILD_CMAKE_BIN} .. \
        -DSERIOUS_PROTON_DIR="${EE_BUILD_SP}" \
        -DCMAKE_TOOLCHAIN_FILE="${EE_BUILD_EE_CMAKE}/android.toolchain" \
        -DCMAKE_MAKE_PROGRAM="${EE_BUILD_MAKE_BIN}" \
        -DCPACK_PACKAGE_VERSION_MAJOR="${EE_BUILD_DATE:0:4}" \
        -DCPACK_PACKAGE_VERSION_MINOR="${EE_BUILD_DATE:4:2}" \
        -DCPACK_PACKAGE_VERSION_PATCH="${EE_BUILD_DATE:6:2}" &&
      make -j 5 &&
      echo "!   Android build complete to ${EE_BUILD_EE_ANDROID}/EmptyEpsilon.apk" )
  else
    echo "X   No targets provided as arguments. Valid arguments: win32 linux android"
  fi
done
