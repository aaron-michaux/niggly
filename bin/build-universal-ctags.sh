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

      # Install to $TOOLS_DIR/bin
      > $(basename $0) --toolchain=gcc --version=v6.0.0

   Repos:

      https://github.com/universal-ctags/ctags/tree/v6.0.0

EOF
}

# ------------------------------------------------------------------------ build

build_it()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d ctags ] ; then
        git clone https://github.com/universal-ctags/ctags.git
    fi
    cd ctags
    git fetch
    git checkout ${VERSION}
 
    export CC="$HOST_CC"
    export CXX="$HOST_CXX"
    unset CFLAGS
    unset CPPFLAGS
    unset CXXFLAGS
    unset LDFLAGS
    unset LIBS
    ./autogen.sh
    ./configure --prefix=$TOOLS_DIR
    nice make -j$(nproc)
    nice make install
}


# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "False" "$@"

# ----------------------------------------------------------------------- action

EXEC="$TOOLS_DIR/bin/ctags"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -x "$EXEC" ] ; then
    ensure_directory "$TOOLS_DIR"
    build_it $VERSION
else
    echo "Skipping installation, executable found: '$EXEC'"
fi





