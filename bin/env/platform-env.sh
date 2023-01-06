#!/bin/sh

# ------------------------------------------------------ Host Platform Variables

export TOOLS_DIR=/opt/tools
export TOOLCHAINS_DIR=/opt/toolchains
export ARCH_DIR=/opt/arch

# The default clang/gcc with the default cxxstd
# Note: on macos, the major versions of these are installed using brew
export DEFAULT_LLVM_VERSION="clang-15.0.6"
export DEFAULT_GCC_VERSION="gcc-12.2.0"

# Tool (host) compilers
export HOST_CC=/usr/bin/gcc
export HOST_CXX=/usr/bin/g++

# These dependencies need to be made, and are then used globally
export CMAKE="$TOOLS_DIR/bin/cmake"

if [ -z ${TRIPLE_LIST+x} ] ; then
    UNAMEM="$(uname -m)"
    export TRIPLE_LIST="${UNAMEM}-linux-gnu ${UNAMEM}-pc-linux-gnu ${UNAMEM}-unknown-linux-gnu"
fi

if [ -z ${PLATFORM+x} ] ; then
    if [ -x "/usr/bin/lsb_release" ] ; then    
        export PLATFORM="ubuntu"
    elif [ -f /etc/fedora-release ] ; then
        export PLATFORM="fedora"
    elif [ "$(uname -s)" = "Darwin" ] ; then
        export PLATFORM="macos"
    elif [ -f /etc/os-release ] && cat /etc/os-release | grep -qi Oracle  ; then
        export PLATFORM="oracle"
    fi
fi

major_version()
{
    echo "$1" | cut -d - -f 2 - | cut -d . -f 1
}

