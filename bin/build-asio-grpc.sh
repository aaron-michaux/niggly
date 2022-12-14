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
      > $(basename $0) --toolchain=gcc --version=v2.3.0

   Repos:

      https://github.com/Tradias/asio-grpc

EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d asio-grpc ] ; then
        git clone https://github.com/Tradias/asio-grpc.git
    fi
    cd asio-grpc
    git fetch
    git checkout ${VERSION}

    # Some patches
    sed -i 's,find_package(asio),SET(_asio_grpc_asio_root "${CMAKE_PREFIX_PATH}/include/boost"),' cmake/AsioGrpcFindPackages.cmake
    
    rm -rf build
    mkdir build
    cd build
    
    $CMAKE -D ASIO_GRPC_BUILD_TESTS=Off               \
           -D CMAKE_MODULE_PATH="$PREFIX/lib/cmake"   \
           -D CMAKE_BUILD_TYPE=Release                \
           -D CMAKE_PREFIX_PATH=$PREFIX               \
           -D CMAKE_INSTALL_PREFIX=$PREFIX            \
           ..
 
    make -j$(nproc)
    make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

FILE="$PREFIX/lib/cmake/asio-grpc/asio-grpcConfig.cmake"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, cmake file found: '$FILE'"
fi


 
