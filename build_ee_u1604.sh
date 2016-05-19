#!/bin/bash
EE_BUILD_HOME=`pwd`
EE_BUILD_EE_PATH="${EE_BUILD_HOME}/EmptyEpsilon"
EE_BUILD_SP_PATH="${EE_BUILD_HOME}/SeriousProton"
EE_BUILD_SFML_VERSION="2.3"
EE_BUILD_SFML_PATH="${EE_BUILD_HOME}/SFML-${EE_BUILD_SFML_VERSION}"
EE_BUILD_DRMINGW_VERSION="0.8" # Unused; we build from master.
EE_BUILD_DRMINGW_PATH="${EE_BUILD_HOME}/drmingw"
EE_BUILD_ZIP_PATH="${EE_BUILD_HOME}/EE_ZIP"
EE_BUILD_MINGW_LIBPATH="$(dirname $(locate libgcc.a | grep win32 | grep i686) 2> /dev/null)"
EE_BUILD_MINGW_USRPATH="$(dirname $(locate libwinpthread-1.dll | grep i686) 2> /dev/null)"
EE_BUILD_DATE="$(date +'%Y%m%d')"
EE_BUILD_CMAKE="${EE_BUILD_EE_PATH}/cmake"

# Update system and install tools.
if [ ! -d "${EE_BUILD_MINGW_LIBPATH}" ]; then
  echo "Installing tools..."
  sudo apt update && sudo apt -y install wget cmake build-essential git libgl1-mesa-dev libxrandr-dev libfreetype6-dev libglew-dev libjpeg-dev libopenal-dev libxcb1-dev libxcb-image0-dev libudev-dev libflac-dev libvorbis-dev unzip zip mingw-w64
  ## Find a better way to get the mingw path!
  sudo updatedb
  EE_BUILD_MINGW_LIBPATH="$(dirname $(locate libgcc.a | grep win32 | grep i686))"
  EE_BUILD_MINGW_USRPATH="$(dirname $(locate libwinpthread-1.dll | grep i686))"
  echo
fi

# Clone repos.
echo "Cloning or updating git repos..."

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

## Get SFML 2.3.x.
if [ ! -d "${EE_BUILD_SFML_PATH}" ]; then
  echo "-   Cloning SFML repo to ${EE_BUILD_SFML_PATH}..."
  git clone https://github.com/SFML/SFML.git -b "${EE_BUILD_SFML_VERSION}.x" "${EE_BUILD_SFML_PATH}"
else
  echo "-   Fetching and merging SFML repo at ${EE_BUILD_SFML_PATH}..."
  ( cd "${EE_BUILD_SFML_PATH}";
    git fetch --all && git merge --ff-only; )
fi
echo

## Get DRMingW for debugging Windows builds.
if [ ! -d "${EE_BUILD_DRMINGW_PATH}" ]; then
  echo "-   Cloning DrMingW repo to ${EE_BUILD_DRMINGW_PATH}..."
  git clone https://github.com/jrfonseca/drmingw.git "${EE_BUILD_DRMINGW_PATH}"
else
  echo "-   Fetching and merging DrMingW repo at ${EE_BUILD_DRMINGW_PATH}..."
  ( cd "${EE_BUILD_DRMINGW_PATH}";
    git fetch --all && git merge --ff-only; )
fi
echo

## Write commit IDs for each repo into a file for reference.
for i in "${EE_BUILD_SP_PATH}" "${EE_BUILD_EE_PATH}" "${EE_BUILD_SFML_PATH}" "${EE_BUILD_DRMINGW_PATH}"
do (
  cd "${i}";
  echo "$(git log --pretty='oneline' -n 1)" > "${i}/commit.log";
); done
echo

# Build the prerequisites.

## Build SFML for Linux.
echo "Building SFML for Linux..."
cd "${EE_BUILD_SFML_PATH}"
### Apply patch for 16.04 until SFML fixes its CMakeLists or Ubuntu fixes GCC.
if [ ! -f 3383b4a472f0bd16a8161fb8760cd3e6333f1782.patch ]; then
  wget --no-clobber http://web.archive.org/web/20160509014317/https://gitlab.peach-bun.com/pinion/SFML/commit/3383b4a472f0bd16a8161fb8760cd3e6333f1782.patch &&
  git apply 3383b4a472f0bd16a8161fb8760cd3e6333f1782.patch
fi
if [ ! -d lin32 ]; then
  mkdir lin32
fi
cd lin32
cmake .. && make && sudo make install
echo

## Build SFML for Windows.
echo "Building SFML for Windows..."
cd "${EE_BUILD_SFML_PATH}"
if [ ! -d win32 ]; then
  mkdir win32
fi
cd win32
### Use the CMake toolchain from EE to make it easier to compile for Windows.
cmake -DCMAKE_TOOLCHAIN_FILE="${EE_BUILD_CMAKE}/mingw.toolchain" -DOPENAL_LIBRARY="${EE_BUILD_SFML_PATH}/extlibs/bin/x86/openal32.dll" ..
make
echo

## Build DrMingW Windows debugging DLLs.
echo "Building DrMingW for Windows..."
cd "${EE_BUILD_DRMINGW_PATH}"
if [ ! -d win32 ]; then
  mkdir win32
fi
cd win32
### Use the CMake toolchain from EE to make it easier to compile for Windows.
cmake -DCMAKE_TOOLCHAIN_FILE="${EE_BUILD_CMAKE}/mingw.toolchain" ..
sudo make install
### Workaround for "-lexchndl" missing dll.
### Find a better way to get the mingw path!
if [ ! -e "${EE_BUILD_MINGW_LIBPATH}/exchndl.dll" ]; then
  sudo ln -s "${EE_BUILD_DRMINGW_PATH}/win32/bin/exchndl.dll" "${EE_BUILD_MINGW_LIBPATH}/"
fi
sudo ldconfig
echo

# Build EmptyEpsilon.

## Build EmptyEpsilon for Linux.
echo "Building EmptyEpsilon for Linux..."
cd "${EE_BUILD_EE_PATH}"
if [ ! -d lin32 ]; then
  mkdir lin32
fi
cd lin32
cmake -DSERIOUS_PROTON_DIR="${EE_BUILD_SP_PATH}/" -DSFML_ROOT="${EE_BUILD_SFML_PATH}/" ..
make
echo

## Build EmptyEpsilon for Windows.
echo "Building EmptyEpsilon for Windows..."
cd "${EE_BUILD_EE_PATH}"
if [ ! -d win32 ]; then
  mkdir win32
fi
cd win32
### Find a better way to get the mingw path!
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS:STRING=-DSFML_STATIC -DCMAKE_TOOLCHAIN_FILE="${EE_BUILD_CMAKE}/mingw.toolchain" -DSERIOUS_PROTON_DIR="${EE_BUILD_SP_PATH}/" -DSFML_ROOT="${EE_BUILD_SFML_PATH}/win32" -DMING_DLL_PATH="${EE_BUILD_MINGW_LIBPATH}/" -DENABLE_CRASH_LOGGER=1 ..
make
echo

# Build a distributable archive.

## Clean and rebuild the distribution directory.
echo "Setting up Zip file..."
cd "${EE_BUILD_EE_PATH}"
python compile_script_docs.py > scripts_docs.html
cd "${EE_BUILD_HOME}"
if [ ! -d "${EE_BUILD_ZIP_PATH}" ]; then
  mkdir "${EE_BUILD_ZIP_PATH}"
fi
if [ -d "${EE_BUILD_ZIP_PATH}/EmptyEpsilon" ]; then
  rm -rf "${EE_BUILD_ZIP_PATH}"/EmptyEpsilon/*
else
  mkdir "${EE_BUILD_ZIP_PATH}/EmptyEpsilon"
fi
echo

## Copy game content into the distribution directory.
echo "Copying folders..."
cp -rv "${EE_BUILD_EE_PATH}/packs" "${EE_BUILD_EE_PATH}/scripts" "${EE_BUILD_EE_PATH}/resources" "${EE_BUILD_ZIP_PATH}/EmptyEpsilon"
echo

echo "Copying binaries..."
cp -v "${EE_BUILD_EE_PATH}/win32/EmptyEpsilon.exe" "${EE_BUILD_EE_PATH}/lin32/EmptyEpsilon" "${EE_BUILD_ZIP_PATH}/EmptyEpsilon"
echo

echo "Copying support files..."
cp -v "${EE_BUILD_EE_PATH}"/artemis_mission_convert* "${EE_BUILD_EE_PATH}/LICENSE" "${EE_BUILD_EE_PATH}/logo.svg" "${EE_BUILD_EE_PATH}/README.md" "${EE_BUILD_EE_PATH}/scripts_docs.html" "${EE_BUILD_ZIP_PATH}/EmptyEpsilon"
echo

echo "Copying DLLs..."
### Find a better way to get the mingw path!
cp -v "${EE_BUILD_SFML_PATH}"/win32/lib/*.dll "${EE_BUILD_SFML_PATH}/extlibs/bin/x86/openal32.dll" "${EE_BUILD_DRMINGW_PATH}"/win32/bin/*.dll "${EE_BUILD_MINGW_LIBPATH}/libstdc++-6.dll" "${EE_BUILD_MINGW_LIBPATH}/libgcc_s_sjlj-1.dll" "${EE_BUILD_MINGW_USRPATH}/libwinpthread-1.dll" "${EE_BUILD_ZIP_PATH}/EmptyEpsilon"
echo

echo "Copying git commit references..."
for i in "${EE_BUILD_SP_PATH}" "${EE_BUILD_EE_PATH}" "${EE_BUILD_SFML_PATH}" "${EE_BUILD_DRMINGW_PATH}"
do (
  echo "${i}";
  echo "${i}" >> "${EE_BUILD_ZIP_PATH}/EmptyEpsilon/commit.log";
  cat "${i}/commit.log";
  cat "${i}/commit.log" >> "${EE_BUILD_ZIP_PATH}/EmptyEpsilon/commit.log"
  echo "-----" >> "${EE_BUILD_ZIP_PATH}/EmptyEpsilon/commit.log";
  echo "-----";
); done
echo

## Zip the distribution directory.
echo "Compressing build..."
cd "${EE_BUILD_ZIP_PATH}"
EE_BUILD_COMMIT="$(head ${EE_BUILD_EE_PATH}/commit.log | cut -d ' ' -f 1)"
EE_BUILD_ZIP_FILE="${EE_BUILD_ZIP_PATH}/EmptyEpsilon_${EE_BUILD_DATE}_${EE_BUILD_COMMIT}.zip"
zip -r "${EE_BUILD_ZIP_FILE}" ./EmptyEpsilon
echo

# Wrap up and note the end of the build.

## If there's a /vagrant directory, assume we're using vagrant and copy the zips to /vagrant.
if [ -d /vagrant ]; then
  cp "${EE_BUILD_ZIP_FILE}" /vagrant
  cd "${EE_BUILD_HOME}"

  echo "Changing owner of all files in the buildhome directory to vagrant in case we need to interactively work with these files."
  chown -R vagrant:vagrant "${EE_BUILD_HOME}"
  echo "EmptyEpsilon built to /vagrant/${EE_BUILD_ZIP_FILE}."
## Otherwise, just say we're done.
else
  echo "EmptyEpsilon built to ${EE_BUILD_ZIP_FILE}."
fi
