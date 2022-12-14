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
      > $(basename $0) --toolchain=gcc --version=1.12.1

   Repos:

      https://github.com/google/googletest

EOF
}

# ------------------------------------------------------------------------ build

build_google_test()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d googletest ] ; then
        git clone https://github.com/google/googletest.git
    fi
    cd googletest
    git fetch
    git checkout release-${VERSION}
    rm -rf build
    mkdir build
    cd build
    
    $CMAKE -D CMAKE_BUILD_TYPE=Release            \
           -D CMAKE_PREFIX_PATH=$PREFIX           \
           -D CMAKE_INSTALL_PREFIX:PATH=$PREFIX   \
           ..

    nice make -j$(nproc)
    nice make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

PKG_FILE="$PKG_CONFIG_PATH/gtest.pc"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$PKG_FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build_google_test $VERSION
else
    echo "Skipping installation, pkg-config file found: '$PKG_FILE'"
fi


