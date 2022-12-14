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
      > $(basename $0) --toolchain=gcc --version=tools-release-58

   Repos:

      https://github.com/unicode-org/icu

EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d icu ] ; then
        git clone https://github.com/unicode-org/icu.git
    fi
    cd icu
    git fetch
    git checkout ${VERSION}

    cd icu4c/source

    unset LIBS
    
    nice ./configure --prefix=$PREFIX --enable-shared --enable-static --enable-release --enable-icu-config --enable-rpath
    nice make clean
    nice make -j$(nproc)
    nice make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

FILE="$PKG_CONFIG_PATH/icu-i18n.pc"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, pkg-config file found: '$FILE'"
fi


 
