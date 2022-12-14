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
      > $(basename $0) --toolchain=gcc --version=v1.51.1

   Repos:

      https://github.com/grpc/grpc.git

EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d grpc ] ; then
        git clone --recursive https://github.com/grpc/grpc.git
    fi
    cd grpc
    git fetch
    git checkout .
    git checkout ${VERSION}
    git submodule update --init --recursive
    
    rm -rf build
    mkdir build
    cd build
    
    $CMAKE -D gRPC_BUILD_TEST=On                      \
           -D gRPC_BUILD_GRPC_CSHARP_PLUGIN=Off       \
           -D gRPC_BUILD_GRPC_NODE_PLUGIN=Off         \
           -D gRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=Off  \
           -D gRPC_BUILD_GRPC_PHP_PLUGIN=Off          \
           -D gRPC_BUILD_GRPC_RUBY_PLUGIN=Off         \
           -D protobuf_WITH_ZLIB=On                   \
           -D CMAKE_BUILD_TYPE=Release                \
           -D CMAKE_PREFIX_PATH=$PREFIX               \
           -D CMAKE_INSTALL_PREFIX=$PREFIX            \
           ..
 
    nice make -j$(nproc)
    nice make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

FILE="$PREFIX/lib/cmake/grpc/gRPCConfig.cmake"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, cmake file found: '$FILE'"
fi


 
