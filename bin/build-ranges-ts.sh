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
      > $(basename $0) --toolchain=gcc --version=0.12.0

   Repos:

      https://github.com/ericniebler/range-v3

EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d range-v3 ] ; then
        git clone https://github.com/ericniebler/range-v3.git
    fi
    cd range-v3
    git fetch
    git checkout ${VERSION}
    rm -rf build
    mkdir build
    cd build

    $CMAKE -D BUILD_TESTING=Off                   \
           -D RANGES_CXX_STD=$CXXSTD              \
           -D RANGE_V3_TESTS=Off                  \
           -D RANGE_V3_EXAMPLES=Off               \
           -D CMAKE_BUILD_TYPE=Release            \
           -D CMAKE_PREFIX_PATH=$PREFIX           \
           -D CMAKE_INSTALL_PREFIX:PATH=$PREFIX   \
           ..

    nice make -j$(nproc) VERBOSE=1
    nice make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

FILE="$PREFIX/lib/cmake/range-v3/range-v3-config.cmake"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, cmake file found: '$FILE'"
fi


 
