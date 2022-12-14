
# Installation

Building and installing clang/gcc and various libraries

 1. Installation shell-scrips are in `bin`; all scripts have a `-h|--help` switch.
 2. Toolchains are installed to `/opt/toolchains/<toolchain>`.
 3. Libraries are built with the custom installed clang/gcc, using either libcxx, or gnu's stdcxx.
 4. The installation `PREFIX` is `/opt/arch/<triple>-<toolchain>-<libcxx|stdcxx>`.
 5. Tools (like cmake) are installed to `/opt/tools`.

```
# Idempotent script that downloads, builds, and installs everything
bin/all.sh
```

