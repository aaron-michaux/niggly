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
      > $(basename $0) --toolchain=gcc --version=master

   Repos:

      https://github.com/ofats/any_invocable

EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d any_invocable ] ; then
        git clone https://github.com/ofats/any_invocable.git
    fi
    cd any_invocable
    git fetch
    git checkout ${VERSION}

    cp -a include/ofats $PREFIX/include/
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

INC_FILE="$PREFIX/include/ofats/invocable.h"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$INC_FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, include file found: '$INC_FILE'"
fi


 
