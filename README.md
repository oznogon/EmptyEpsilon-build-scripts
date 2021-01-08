# EmptyEpsilon-build-scripts

Build scripts for Ubuntu and macOS hosts that automatically install or build
any prerequisites.

-   `build_ee_d10.sh`: Run on Debian 10 with `win32, `linux`, and/or `android`
    arguements to build for those targets.
-   `build_ee_u1804.sh`: Run on Ubuntu 18.04 with `win32`, `linux`, and/or
    `android` arguments to build for those targets.
-   `build_ee_u1604.sh`: Run on Ubuntu 16.04, same options.
-   `build_ee_macos.sh`: Run on macOS. Does not take arguments and builds
    only for the macOS target. Note that builds made with Xcode 10 or newer
    might not work on macOS 10.13 or older.

## Other arguments

-   `nobuild`: Compile the executable, but don't build a package or archive.
-   `noupdate`: Do not update OS packages or repositories.
-   `threads<N>`: Set the number of threads for compilation. Defaults to
    `threads3`, equivalent to `make -j3`.

## Microsoft Visual Studio

Place the `CMakeSettings.json` in this repository inside the `EmptyEpsilon`
repository to build using MSVC. You'll also need to download 32-bit SFML
libraries ("Visual C++ 15 (2017) - 32-bit" on [the SFML website](https://www.sfml-dev.org/download/sfml/2.5.1/))
and place the SFML-2.5.1 directory as a child of `EmptyEpsilon-build-scripts`.
