#!/bin/bash

set -e

source "$(cd "$(dirname "$0")" ; pwd)/env.sh"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTION* <version>

      Generalized constexpr math

   Options:

$(show_help_snippet)

   Examples:

      # Install using 'gcc'
      > $(basename $0) --toolchain=gcc --version=liburing-2.3

   Repos:

      https://github.com/axboe/liburing

EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d liburing ] ; then
        git clone https://github.com/axboe/liburing.git
    fi
    cd liburing
    git fetch
    git checkout ${VERSION}

    ./configure --prefix=$PREFIX --cc=$CC --cxx=$CXX
    make install -j$(nproc)
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

FILE="$PKG_CONFIG_PATH/liburing.pc"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, pkg-config file found: '$FILE'"
fi


 
