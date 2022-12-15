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

      # Install valgrind 3.20 to $TOOLS_DIR/bin
      > $(basename $0) --toolchain=gcc --version=3.20.0

   Repos:

      http://www.valgrind.org/downloads

EOF
}

# ------------------------------------------------------------------------ build

build_valgrind()
{
    VALGRIND_VERSION="$1"
    URL="https://sourceware.org/pub/valgrind/valgrind-${VALGRIND_VERSION}.tar.bz2"

    cd "$TMPD"
    VAL_D="valgrind-${VALGRIND_VERSION}"
    VAL_F="valgrind-${VALGRIND_VERSION}.tar.bz2"
    if [ ! -f "$VAL_F" ] ; then
        wget "$URL"
    fi
    rm -rf "$VAL_D"
    bzip2 -dc "$VAL_F" | tar -xf -
    cd "$VAL_D"
    export CC=$HOST_CC
    export CXX=$HOST_CXX
    unset CFLAGS
    unset CXXFLAGS
    unset LDFLAGS
    unset LIBS    
    nice ./autogen.sh
    nice ./configure --prefix="$TOOLS_DIR"
    nice make -j$(nproc)
    nice make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "False" "$@"

# ----------------------------------------------------------------------- action

EXEC="$TOOLS_DIR/bin/valgrind"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -x "$EXEC" ] ; then
    ensure_directory "$TOOLS_DIR"
    build_valgrind $VERSION
else
    echo "Skipping installation, executable found: '$EXEC'"
fi

