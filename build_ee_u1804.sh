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
EE_BUILD_CMAKE="${EE_BUILD_EE}/cmake"
EE_BUILD_MAKE="/usr/bin/make"
EE_UPDATE="yes"
EE_THREADS="3"

set -e

# Require an argument
if [ "$#" == "0" ]
then
  echo "X   No targets provided as arguments. Valid targets: win32 linux android"
  exit 1
fi

for arg in "$@"
do
  if [ "${arg:0:2}" == "20" ]
  then
    EE_BUILD_DATE="${arg}"
  elif [ "${arg:0:2}" == "00" ]
  then
    EE_BUILD_DATE="00000000"
  elif [ "${arg}" == "noupdate" ]
  then
    echo "!   Skipping repo cloning, tool installation, and updates."
    EE_UPDATE="no"
  elif [ "${arg:0:7}" == "threads" ]
  then
    EE_THREADS="${arg:7:2}"
  fi
done

echo "-   Using ${EE_BUILD_DATE} as the EmptyEpsilon version."
EE_BUILD_DATE_YEAR="${EE_BUILD_DATE:0:4}"
EE_BUILD_DATE_MONTH="${EE_BUILD_DATE:4:2}"
EE_BUILD_DATE_DAY="${EE_BUILD_DATE:6:2}"

if [ "${EE_UPDATE}" == "yes" ]
then
  echo "-   Installing, cloning, or updating repos and tools."
  # Update the index. CI loves loves loves stale indices.
  sudo apt-get update &&

  # Update the system if it hasn't been in the last 12 hours.
  if [ -z "$(find /var/cache/apt/pkgcache.bin -mmin -720)" ]
  then
    echo "Updating system..."
    sudo apt-get -y upgrade &&
      echo "!   System updated."
  fi

  # Install tools.
  echo "Installing tools..."
  sudo apt-get -y install git build-essential libx11-dev \
    libxrandr-dev mesa-common-dev libglu1-mesa-dev \
    libudev-dev libglew-dev libjpeg-dev libfreetype6-dev \
    libopenal-dev libsndfile1-dev libxcb1-dev \
    libxcb-image0-dev mingw-w64 cmake gcc g++ zip \
    unzip p7zip-full python3-minimal openjdk-8-jdk libxcursor-dev && # libsfml-dev
    echo "!   Tools installed."

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
fi

# Write commit IDs for each repo into a file for reference.
echo "Saving commit IDs..."
for i in "${EE_BUILD_SP}" "${EE_BUILD_EE}" "${EE_BUILD_SFML}"
do
  ( cd "${i}" &&
    echo "-   $(git log --pretty='oneline' -n 1)" )
done


for arg in "$@"
do
  if [ "$arg" == "win32" ]
  then
    # Build EmptyEpsilon for Windows.
    echo "Building EmptyEpsilon for win32..."
    # discord/gamesdk-and-dispatch#100
    # discord_game_sdk.h uses uppercase Windows.h.
    # If we don't have one too, the build breaks.
    # Computers are the single greatest advancement in the history of humanity.
    if [ ! -f "/usr/share/mingw-w64/include/Windows.h" ]
    then
      for i in $(dirname $(find /usr -iname windows.h))
      do
        sudo ln -s ${i}/windows.h ${i}/Windows.h
      done
    fi
    ( cd "${EE_BUILD_EE}" &&
        mkdir -p "${EE_BUILD_EE_WIN32}" &&
        cd "${EE_BUILD_EE_WIN32}" &&
        cmake .. -DSERIOUS_PROTON_DIR="${EE_BUILD_SP}" \
          -DCMAKE_TOOLCHAIN_FILE="${EE_BUILD_CMAKE}/mingw.toolchain" \
          -DCMAKE_MAKE_PROGRAM="${EE_BUILD_MAKE}" \
          -DCPACK_PACKAGE_VERSION_MAJOR="${EE_BUILD_DATE_YEAR}" \
          -DCPACK_PACKAGE_VERSION_MINOR="${EE_BUILD_DATE_MONTH}" \
          -DCPACK_PACKAGE_VERSION_PATCH="${EE_BUILD_DATE_DAY}" &&
        make -j"${EE_THREADS}" package &&
        echo "!   win32 build complete to ${EE_BUILD_EE_WIN32}/EmptyEpsilon.zip" )
  elif [ "$arg" == "linux" ]
  then
    # Build EmptyEpsilon for Debian.
    echo "Building EmptyEpsilon for Debian..."
    ( cd "${EE_BUILD_EE}" &&
        mkdir -p "${EE_BUILD_EE_LINUX}" &&
        cd "${EE_BUILD_EE_LINUX}" &&
        cmake .. -DSERIOUS_PROTON_DIR="${EE_BUILD_SP}" \
          -DCMAKE_MAKE_PROGRAM="${EE_BUILD_MAKE}" \
          -DCPACK_PACKAGE_VERSION_MAJOR="${EE_BUILD_DATE_YEAR}" \
          -DCPACK_PACKAGE_VERSION_MINOR="${EE_BUILD_DATE_MONTH}" \
          -DCPACK_PACKAGE_VERSION_PATCH="${EE_BUILD_DATE_DAY}" &&
        make -j"${EE_THREADS}" &&
	cpack \
	  -G DEB \
	  -D CPACK_PACKAGE_CONTACT=https://github.com/daid/ \
	  -R "${EE_BUILD_DATE_YEAR}.${EE_BUILD_DATE_MONTH}.${EE_BUILD_DATE_DAY}" &&
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
        cmake .. -DSERIOUS_PROTON_DIR="${EE_BUILD_SP}" \
          -DCMAKE_TOOLCHAIN_FILE="${EE_BUILD_CMAKE}/android.toolchain" \
          -DCMAKE_MAKE_PROGRAM="${EE_BUILD_MAKE}" \
          -DCPACK_PACKAGE_VERSION_MAJOR="${EE_BUILD_DATE_YEAR}" \
          -DCPACK_PACKAGE_VERSION_MINOR="${EE_BUILD_DATE_MONTH}" \
          -DCPACK_PACKAGE_VERSION_PATCH="${EE_BUILD_DATE_DAY}" &&
        make -j"${EE_THREADS}" &&
        echo "!   Android build complete to ${EE_BUILD_EE_ANDROID}/EmptyEpsilon.apk" )
  fi
done
