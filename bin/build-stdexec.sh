#!/bin/bash

set -e

source "$(cd "$(dirname "$0")" ; pwd)/env/cross-env.sh"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTION* <version>

   Options:

$(show_help_snippet)

   Examples:

      # Install using 'gcc'
      > $(basename $0) --toolchain=gcc --version=218931e835b0313c67be469adb721df8c43eb684

   Repos:

      https://github.com/NVIDIA/stdexec

EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d stdexec ] ; then
        git clone https://github.com/NVIDIA/stdexec.git
    fi
    cd stdexec
    git fetch
    git checkout .
    git checkout ${VERSION}

    rm -rf build
    mkdir build
    cd build

    export CXXFLAGS="$CXXFLAGS -Wno-unused-but-set-variable"
    
    $CMAKE -D BUILD_TESTING=Off                     \
           -D BUILD_GMOCK=Off                       \
           -D INSTALL_GTEST=Off                     \
           -D Coroutines_FOUND=On                   \
           -D CXX_COROUTINES_HAVE_COROUTINES=On     \
           -D CMAKE_CXX_FLAGS="$CXXFLAGS"           \
           -D CMAKE_BUILD_TYPE=Release              \
           -D CMAKE_PREFIX_PATH=$PREFIX             \
           -D CMAKE_INSTALL_PREFIX=$PREFIX          \
           ..
    
    nice make -j$(nproc)
    nice make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

FILE="$PREFIX/lib/cmake/stdexec/stdexec-targets.cmake"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, cmake file found: '$FILE'"
fi


 
