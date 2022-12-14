#!/bin/bash

set -e

source "$(cd "$(dirname "$0")" ; pwd)/env.sh"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTION* <version>

   Options:

$(show_help_snippet)

   Examples:

      # Install using 'gcc'
      > $(basename $0) --toolchain=gcc --version=v1.7.1

   Repos:

      https://github.com/google/benchmark

EOF
}

# ------------------------------------------------------------------------ build

build_google_benchmark()
{
    VERSION="$1"

    if [ "$IS_GCC" = "True" ] && [ "$STDLIB" = "libcxx" ] ; then
        echo "Does not build with libc++ under gcc, aborting" 1>&2
        exit 1
    fi

    cd "$TMPD"
    if [ ! -d benchmark ] ; then
        git clone https://github.com/google/benchmark.git
    fi
    cd benchmark
    git fetch
    git checkout ${VERSION}    
    rm -rf build
    mkdir build
    cd build
    
    export CXXFLAGS="-Wno-maybe-uninitialized $CXXFLAGS"
    $CMAKE -D BENCHMARK_DOWNLOAD_DEPENDENCIES=On  \
           -D CMAKE_BUILD_TYPE=Release            \
           -D CMAKE_PREFIX_PATH=$PREFIX           \
           -D CMAKE_INSTALL_PREFIX:PATH=$PREFIX   \
           ..

    make -j$(nproc)
    make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

PKG_FILE="$PKG_CONFIG_PATH/benchmark.pc"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$PKG_FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build_google_benchmark $VERSION
else
    echo "Skipping installation, pkg-config file found: '$PKG_FILE'"
fi

