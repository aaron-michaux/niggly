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
      > $(basename $0) --toolchain=gcc --version=v3.2.1

   Repos:

      https://github.com/catchorg/Catch2

EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d Catch2 ] ; then
        git clone https://github.com/catchorg/Catch2.git
    fi
    cd Catch2
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

FILE="$PREFIX/lib/cmake/Catch2/Catch.cmake"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, cmake file found: '$FILE'"
fi


 
