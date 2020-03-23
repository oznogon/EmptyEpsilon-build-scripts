# EmptyEpsilon-build-scripts

Build scripts for Ubuntu and macOS hosts that automatically install or build
any prerequisites.

-   `build_ee_u1804.sh`: Run on Ubuntu 18.04 with `win32`, `linux`, and/or
    `android` arguments to build for those targets.
-   `build_ee_u1604.sh`: Run on Ubuntu 16.04, same options.
-   `build_ee_macos.sh`: Run on macOS. Does not take arguments and builds
    only for the macOS target. Note that builds made with Xcode 10 or newer
    might not work on macOS 10.13 or older.
