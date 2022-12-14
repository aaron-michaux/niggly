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
      > $(basename $0) --toolchain=gcc --version=9.1.0

   Repos:

      https://github.com/fmtlib/fmt

EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d fmt ] ; then
        git clone https://github.com/fmtlib/fmt.git
    fi
    cd fmt
    git fetch
    git checkout ${VERSION}
    rm -rf build
    mkdir build
    cd build

    $CMAKE -D FMT_TEST=Off                        \
           -D CMAKE_BUILD_TYPE=Release            \
           -D CMAKE_PREFIX_PATH=$PREFIX           \
           -D CMAKE_INSTALL_PREFIX:PATH=$PREFIX   \
           ..

    nice make -j$(nproc)
    nice make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

FILE="$PREFIX/lib/cmake/fmt/fmt-config.cmake"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, cmake file found: '$FILE'"
fi


 
