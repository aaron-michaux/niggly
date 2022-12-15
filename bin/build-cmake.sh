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

      # Install cmake v3.25.1 to $TOOLS_DIR/bin
      > $(basename $0) --toolchain=gcc --version=v3.25.1

   Repos:

      https://github.com/Kitware/CMake

EOF
}

# ------------------------------------------------------------------------ build

build_cmake()
{
    local VERSION="$1"
    local FILE_BASE="cmake-$VERSION"
    local FILE="$FILE_BASE.tar.gz"

    cd "$TMPD"
    wget "https://github.com/Kitware/CMake/archive/refs/tags/$VERSION.tar.gz"
    cat "$VERSION.tar.gz" | gzip -dc | tar -xf -

    cd "CMake-${VERSION:1}"
    nice ./configure --prefix="$TOOLS_DIR"
    nice make -j$(nproc)
    nice make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "False" "$@"

# ----------------------------------------------------------------------- action

EXEC="$TOOLS_DIR/bin/cmake"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -x "$EXEC" ] ; then
    ensure_directory "$TOOLS_DIR"
    build_cmake $VERSION
else
    echo "Skipping installation, executable found: '$EXEC'"
fi


