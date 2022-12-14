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
      > $(basename $0) --toolchain=gcc --version=v3.7.1

   Repos:

      https://github.com/hanickadot/compile-time-regular-expressions.git

EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d compile-time-regular-expressions ] ; then
        git clone https://github.com/hanickadot/compile-time-regular-expressions.git
    fi
    cd compile-time-regular-expressions
    git fetch
    git checkout ${VERSION}
    rm -rf build
    mkdir build
    cd build

    $CMAKE -D CMAKE_BUILD_TYPE=Release            \
           -D CMAKE_PREFIX_PATH=$PREFIX           \
           -D CMAKE_INSTALL_PREFIX:PATH=$PREFIX   \
           ..

    make -j$(nproc)
    make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

INC_FILE="$PREFIX/include/ctre/pcre.hpp"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$INC_FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, include file found: '$INC_FILE'"
fi


 
