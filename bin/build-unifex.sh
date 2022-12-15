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

      # Install using 'gcc'
      > $(basename $0) --toolchain=gcc --version=591ec09e7d51858ad05be979d4034574215f5971

   Repos:

      https://github.com/facebookexperimental/libunifex

EOF
}

# ------------------------------------------------------------------------ build

build()
{
    VERSION="$1"

    cd "$TMPD"
    if [ ! -d libunifex ] ; then
        git clone https://github.com/facebookexperimental/libunifex.git
    fi
    cd libunifex
    git fetch
    git checkout .
    git checkout ${VERSION}

    # Some patches
    sed -i 's,fcoroutines-ts,fcoroutines,g' cmake/FindCoroutines.cmake
    sed -i 's,#include <liburing/io_uring.h>,#include <linux/time_types.h>\n#include <liburing/io_uring.h>,' include/unifex/linux/io_uring_context.hpp
    sed -i 's,size_t count = 0;,size_t count = 0;\n(void)count;,' source/linux/io_epoll_context.cpp
    sed -i 's,size_t count = 0;,size_t count = 0;\n(void)count;,' source/linux/io_uring_context.cpp
    sed -i 's,add_compile_options(-Wall -Wextra -pedantic -Werror),add_compile_options(-Wall -Wextra -Werror),' cmake/unifex_env.cmake
    
    rm -rf build
    mkdir build
    cd build

    export CXXFLAGS="$CXXFLAGS -Wno-unused-but-set-variable"
    
    $CMAKE -D BUILD_TESTING=Off                     \
           -D BUILD_GMOCK=Off                       \
           -D INSTALL_GTEST=Off                     \
           -D Coroutines_FOUND=On                   \
           -D CXX_COROUTINES_HAVE_COROUTINES=On     \
           -D CMAKE_CXX_FLAGS="$CXXFLAGS"           \
           -D CMAKE_BUILD_TYPE=Release              \
           -D CMAKE_PREFIX_PATH=$PREFIX             \
           -D CMAKE_INSTALL_PREFIX=$PREFIX          \
           ..
    
    nice make -j$(nproc)
    nice make install
}

# ------------------------------------------------------------------------ parse

parse_basic_args "$0" "UseToolchain" "$@"

# ----------------------------------------------------------------------- action

FILE="$PREFIX/lib/cmake/unifex/unifexConfig.cmake"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -f "$FILE" ] ; then
    ensure_directory "$ARCH_DIR"
    build $VERSION
else
    echo "Skipping installation, cmake file found: '$FILE'"
fi


 
