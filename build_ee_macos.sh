#!/bin/bash
EE_BUILD_HOME=`pwd`
DYLIBBUNDLER_PATH="${EE_BUILD_HOME}/dylibbundler"
DYLIBBUNDLER_BIN="${DYLIBBUNDLER_PATH}/dylibbundler"
EE_BUILD_EE="${EE_BUILD_HOME}/EmptyEpsilon"
EE_BUILD_EE_MACOS="${EE_BUILD_EE}/_build_macos"
EE_BUILD_EE_ANDROID="${EE_BUILD_EE}/_build_android"
EE_BUILD_EE_ANDROID_KEYSTORE="$HOME/.keystore"
EE_BUILD_EE_ANDROID_KEYSTORE_ALIAS="Android"
EE_BUILD_EE_ANDROID_KEYSTORE_PASSWORD="password"
EE_IS_ANDROID="no"
EE_BUILD_EE_APP="${EE_BUILD_EE_MACOS}/EmptyEpsilon.app"
EE_BUILD_EE_DMG="${EE_BUILD_EE_MACOS}/EmptyEpsilon.dmg"
EE_BUILD_EE_TEMP_DMG="/tmp/tmp.dmg"
EE_BUILD_EE_STAGING_DMG="${EE_BUILD_EE_MACOS}/image_staging"
EE_BUILD_SP="${EE_BUILD_HOME}/SeriousProton"
EE_BUILD_DATE="$(date +'%Y%m%d')"
EE_BUILD_CMAKE="${EE_BUILD_EE}/cmake"
EE_BUILD="yes"
EE_UPDATE="yes"
EE_THREADS="3"

# Explain arguments
if [ "$#" == "0" ]
then
  echo "X   No targets provided as arguments. Valid targets: macos android. Assuming macos"
fi

# Parse version and thread arguments
for arg in "$@"
do
  if [ "${arg}" == "android" ]
  then
    EE_IS_ANDROID="yes"
  elif [ "${arg:0:2}" == "20" ] || [ "${arg}" == "00000000" ]
  then
    EE_BUILD_DATE="${arg}"
  elif [ "${arg}" == "noupdate" ]
  then
    EE_UPDATE="no"
  elif [ "${arg}" == "nobuild" ]
  then
    EE_BUILD="no"
  elif [ "${arg:0:7}" == "threads" ]
  then
    EE_THREADS="${arg:7:2}"
  fi
done
echo "-   Using ${EE_THREADS} threads to build (make -j${EE_THREADS}).";

EE_BUILD_DATE_YEAR="${EE_BUILD_DATE:0:4}"
EE_BUILD_DATE_MONTH="${EE_BUILD_DATE:4:2}"
EE_BUILD_DATE_DAY="${EE_BUILD_DATE:6:2}"

if [ "${EE_UPDATE}" == "yes" ]
then
  # Install XCode.
  xcode-select --install

  # Install cmake and SFML via Homebrew.
  brew install cmake sfml

  # Get dylibbundler.
  if [ ! -d "${DYLIBBUNDLER_PATH}" ]
  then
    echo "Cloning dylibbundler..."
    git clone https://github.com/auriamg/macdylibbundler "${DYLIBBUNDLER_PATH}" &&
      echo "!   dylibbundler source downloaded."
  fi

  # Build dylibbundler.
  if [ ! -f "${DYLIBBUNDLER_BIN}" ]
  then
    echo "Building dyllibbundler..."
    ( cd "${DYLIBBUNDLER_PATH}" &&
        make &&
        echo "!   dylibbundler built." )
  fi

  # Clone SeriousProton and EmptyEpsilon.
  if [ ! -d "${EE_BUILD_SP}" ]
  then
    echo "Cloning SeriousProton repo to ${EE_BUILD_SP}..."
    git clone https://github.com/daid/SeriousProton.git "${EE_BUILD_SP}" &&
      echo "!   SeriousProton source downloaded."
  else
    echo "Fetching and fast-forwarding SeriousProton repo at ${EE_BUILD_SP}..."
    ( cd "${EE_BUILD_SP}"
      git fetch --all && git merge --ff-only &&
        echo "!   SeriousProton source updated." )
  fi

  if [ ! -d "${EE_BUILD_EE}" ]
  then
    echo "Cloning EmptyEpsilon repo to ${EE_BUILD_EE}..."
    git clone https://github.com/daid/EmptyEpsilon.git "${EE_BUILD_EE}"
  else
    echo "Fetching and fast-forwarding EmptyEpsilon repo at ${EE_BUILD_EE}..."
    ( cd "${EE_BUILD_EE}"
      git fetch --all && git merge --ff-only &&
        echo "!   EmptyEpsilon source updated." )
  fi
fi

if [ "${EE_IS_ANDROID}" == "yes" ]
then
  # Install OpenJDK 8 from Homebrew; newer versions fail
  brew install openjdk@8

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
    cmake .. -DSERIOUS_PROTON_DIR="${EE_BUILD_SP}" \
      -DCMAKE_TOOLCHAIN_FILE="${EE_BUILD_CMAKE}/android.toolchain" \
      -DCMAKE_MAKE_PROGRAM="${EE_BUILD_MAKE}" \
      -DCPACK_PACKAGE_VERSION_MAJOR="${EE_BUILD_DATE_YEAR}" \
      -DCPACK_PACKAGE_VERSION_MINOR="${EE_BUILD_DATE_MONTH}" \
      -DCPACK_PACKAGE_VERSION_PATCH="${EE_BUILD_DATE_DAY}" &&
    make -j"${EE_THREADS}" &&
    echo "!   Android build complete to ${EE_BUILD_EE_ANDROID}/EmptyEpsilon.apk" )
# Build for macOS.
else
  ( mkdir -p "${EE_BUILD_EE_MACOS}" &&
    cd "${EE_BUILD_EE_MACOS}" &&
    echo "Building macOS app to ${EE_BUILD_EE_APP}..." &&
    cmake .. \
      -DSERIOUS_PROTON_DIR="${EE_BUILD_SP}" \
      -DCPACK_PACKAGE_VERSION_MAJOR="${EE_BUILD_DATE_YEAR}" \
      -DCPACK_PACKAGE_VERSION_MINOR="${EE_BUILD_DATE_MONTH}" \
      -DCPACK_PACKAGE_VERSION_PATCH="${EE_BUILD_DATE_DAY}" &&
    GL_SILENCE_DEPRECATION=1 make -j"${EE_THREADS}" &&
    echo "!   macOS app build complete to ${EE_BUILD_EE_APP}" &&
    if [ "${EE_BUILD}" == "yes" ]
    then
      make install &&
      echo "-   Bundling dependencies..." &&
      "${DYLIBBUNDLER_BIN}" \
        --overwrite-dir \
        --bundle-deps \
        --search-path "/usr/local/lib" \
        --fix-file "${EE_BUILD_EE_APP}/Contents/MacOS/EmptyEpsilon" \
        --dest-dir "${EE_BUILD_EE_APP}/Contents/libs" &&
      echo "!   Dependencies bundled." &&
      echo "Building macOS DMG (disk image) to ${EE_BUILD_EE_DMG}..." &&
      if [ -d "${EE_BUILD_EE_STAGING_DMG}" ]
      then
        rm -rf "${EE_BUILD_EE_STAGING_DMG}"
      fi
      mkdir -p "${EE_BUILD_EE_STAGING_DMG}" &&
      cp -r \
        "${EE_BUILD_EE_APP}" \
        "${EE_BUILD_EE_MACOS}/script_reference.html" \
        "${EE_BUILD_EE_STAGING_DMG}/" &&
      hdiutil \
        create "${EE_BUILD_EE_TEMP_DMG}" \
        -ov \
        -volname "EmptyEpsilon ${EE_BUILD_DATE}" \
        -fs HFS+ \
        -srcfolder "${EE_BUILD_EE_STAGING_DMG}" &&
      rm -rf "${EE_BUILD_EE_DMG}" &&
      hdiutil \
        convert "${EE_BUILD_EE_TEMP_DMG}" \
        -format UDZO \
        -o "${EE_BUILD_EE_DMG}" &&
      echo "!   macOS DMG build complete to ${EE_BUILD_EE_DMG}" &&
      echo "-   Cleaning up temporary image creation files..." &&
      rm -rf "${EE_BUILD_EE_TEMP_DMG}" "${EE_BUILD_EE_STAGING_DMG}" &&
      echo "!   Temporary image creation files deleted."
    fi )
fi
