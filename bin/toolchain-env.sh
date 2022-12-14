#!/bin/bash

set -e

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTIONS...

   Options:      

      -p|--print                       Print the set environment variables
      --write-make-env-inc             Write include file for make that sets the environment

      --cc=<cc compiler>
      --gcc-installation=<directory>
      --clang-installation=<directory>
      --stdlib=<libcxx|stdcxx>
      --build-config=<debug|release|asan|usan|tsan>
      --lto=<True|False>
      --coverage=<True|False>
      --unity=<True|False>
      --build-tests=<True|False>
      --build-examples=<True|False>
      --benchmark=<True|False>

EOF
}

# -------------------------------------------------------------------------------------------- parse

(( $# == 0 )) && show_help && exit 0
for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

PRINT="False"
WRITE_MAKE_ENV_INC="False"
TARGET=""
TOOL=""
GCC_SUFFIX=""
GCC_INSTALLATION=""
CLANG_INSTALLATION=""
STDLIB=""
BUILD_CONFIG="debug"
LTO="False"
COVERAGE="False"
UNITY="False"
BUILD_TESTS="False"
BUILD_EXAMPLES="False"
BENCHMARK="False"
for ARG in "$@" ; do
    LHS="$(echo "$ARG" | awk -F= '{ print $1 }')"
    RHS="$(echo "$ARG" | awk -F= '{ print $2 }')"

    [ "$ARG" = "-p" ] || [ "$ARG" = "--print" ] && PRINT="True" && continue
    [ "$ARG" = "--write-make-env-inc" ] && WRITE_MAKE_ENV_INC="True" && continue
    
    [ "$LHS" = "--target" ] && TARGET="$RHS" && continue
    [ "$LHS" = "--toolchain" ] && TOOL="$RHS" && continue
    [ "$LHS" = "--gcc-suffix" ] && GCC_SUFFIX="$RHS" && continue
    [ "$LHS" = "--gcc-installation" ] && GCC_INSTALLATION="$RHS" && continue
    [ "$LHS" = "--clang-installation" ] && CLANG_INSTALLATION="$RHS" && continue
    [ "$LHS" = "--stdlib" ] && STDLIB="$RHS" && continue
    [ "$LHS" = "--build-config" ] && BUILD_CONFIG="$RHS" && continue
    [ "$LHS" = "--lto" ] && LTO="$RHS" && continue
    [ "$LHS" = "--coverage" ] && COVERAGE="$RHS" && continue
    [ "$LHS" = "--unity" ] && UNITY="$RHS" && continue
    [ "$LHS" = "--build-tests" ] && BUILD_TESTS="$RHS" && continue
    [ "$LHS" = "--build-examples" ] && BUILD_EXAMPLES="$RHS" && continue
    [ "$LHS" = "--benchmark" ] && BENCHMARK="$RHS" && continue

    echo "Unexpected argument: '$ARG'" 1>&2 && exit 1
done

# ------------------------------------------------------------------------------------ sanity checks

HAS_ERROR="False"
test_in()
{
    SWITCH="$1"
    VALUE="$2"
    LIST="$3"
    for ARG in $LIST ; do
        [ "$VALUE" = "$ARG" ] && return 0 || true
    done
    echo "Switch ${SWITCH}=${VALUE} expected a value in [$LIST]" 1>&2
    HAS_ERROR="True"
}

test_in --toolchain $TOOL "gcc clang"
test_in --stdlib $STDLIB "libcxx stdcxx"
test_in --build-config $BUILD_CONFIG "'' debug release asan usan tsan"
test_in --lto $LTO "True False"
test_in --coverage $COVERAGE "True False"
test_in --unity $UNITY "True False"
test_in --build-tests $BUILD_TESTS "True False"
test_in --build-examples $BUILD_EXAMPLES "True False"
test_in --benchmark $BENCHMARK "True False"

if [ "$TOOL" = "gcc" ] && [ ! -d "$GCC_INSTALLATION" ] ; then
    echo "gcc specified, but failed to find --gcc-installation=$GCC_INSTALLATION"
fi
if [ "$TOOL" = "clang" ] && [ ! -d "$CLANG_INSTALLATION" ] ; then
    echo "clang specified, but failed to find --clang-installation=$CLANG_INSTALLATION"
fi

if [ "$TARGET" = "" ] && [ "$WRITE_MAKE_ENV_INC" = "True" ] ; then
    echo "Target must be set to calculate build directory!" 1>&2
    HAS_ERROR="True"
fi

[ "$HAS_ERROR" = "True" ] && exit 1 || true

# --------------------------------------------------------------------------------- Useful Functions

find_gcov()
{
    local GCC_INSTALLATION="$1"
    if [ -d "$GCC_INSTALLATION" ] ; then
        find "$GCC_INSTALLATION" -maxdepth 1 -name 'gcov*' -type f -o -name 'gcov*' -type l | grep -v gcovr | grep -v gcov-dump | grep -v gcov-tool | sort -g -k 2 -t - | tail -n 1
    fi
}

# ----------------------------------------------------------------------- Base Environment Varialbes

# --Host Platform Variables
OPERATING_SYSTEM="unknown"
if [ -x /usr/bin/lsb_release ] && lsb_release -a 2>/dev/null | grep -q Ubuntu ; then
    OPERATING_SYSTEM="ubuntu"
elif [ -f /etc/fedora-release ] ; then
    OPERATING_SYSTEM="fedora"
elif [ "$(uname -s)" = "Darwin" ] ; then
    OPERATING_SYSTEM="macos"
fi

# -- The Build Directory
UNIQUE_DIR="${TOOL}-${CONFIG}"
[ "$BUILD_TESTS" = "True" ] && UNIQUE_DIR="test-${UNIQUE_DIR}"
[ "$LTO" = "True" ]         && UNIQUE_DIR="${UNIQUE_DIR}-lto"
[ "$BENCHMARK" = "True" ]   && UNIQUE_DIR="bench-${UNIQUE_DIR}"
[ "$COVERAGE" = "True" ] || [ "$COVERAGE_HTML" = "True" ] && UNIQUE_DIR="coverage-${UNIQUE_DIR}"
BUILDDIR="/tmp/build-${USER}/${UNIQUE_DIR}/${TARGET_FILE}"

# -- Make-env.inc file
MAKE_ENV_INC_FILE=$BUILDDIR/make-env.inc

# ------------------------------------------------------------------------------------ Find Binaries

if [ "$TOOL" = "gcc" ] ; then
    TOOLCHAIN_ROOT="$GCC_INSTALLATION"
    CC="$GCC_INSTALLATION/bin/gcc${GCC_SUFFIX}"
    CXX="$GCC_INSTALLATION/bin/g++${GCC_SUFFIX}"
    AR="$GCC_INSTALLATION/bin/gcc-ar${GCC_SUFFIX}"
    NM="$GCC_INSTALLATION/bin/gcc-nm${GCC_SUFFIX}"
    RANLIB="$GCC_INSTALLATION/bin/gcc-ranlib${GCC_SUFFIX}"
    GCOV="$GCC_INSTALLATION/bin/gcov${GCC_SUFFIX}"
    LLD="$CLANG_INSTALLATION/bin/ld.lld"    
else
    TOOLCHAIN_ROOT="$CLANG_INSTALLATION"
    CC="$CLANG_INSTALLATION/bin/clang"
    CXX="$CLANG_INSTALLATION/bin/clang++"
    AR="$CLANG_INSTALLATION/bin/llvm-ar"
    NM="$CLANG_INSTALLATION/bin/llvm-nm"
    RANLIB="$CLANG_INSTALLATION/bin/llvm-ranlib"
    GCOV="$GCC_INSTALLATION/bin/gcov${GCC_SUFFIX}"
    LLD="$CLANG_INSTALLATION/bin/ld.lld"
fi

[ ! -x "$CC" ] && echo "Failed to find CC=$CC" 1>&2 && exit 1 || true
[ ! -x "$CXX" ] && echo "Failed to find CXX=$CXX" 1>&2 && exit 1 || true
[ ! -x "$AR" ] && echo "Failed to find AR=$AR" 1>&2 && exit 1 || true
[ ! -x "$NM" ] && echo "Failed to find NM=$NM" 1>&2 && exit 1 || true
[ ! -x "$RANLIB" ] && echo "Failed to find RANLIB=$RANLIB" 1>&2 && exit 1 || true

if [ "$TOOL" = "gcc" ] ; then
    MAJOR_VERSION="$($CC --version | head -n 1 | awk '{ print $NF }' | awk -F. '{ print $1 }'
)"
else
    MAJOR_VERSION="$($CC --version | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }')"
fi

# "Unset" these variables if the files were not found
[ ! -f "$LLD" ]  && LLD=""  || true
[ ! -f "$GCOV" ] && GCOV="" || true

TRIPLE_LIST="$(uname -m)-linux-gnu $(uname -m)-pc-linux-gnu $(uname -m)-unknown-linux-gnu"

# Compile flags
if [ "$STDLIB" = "stdcxx" ] && [ "$GCC_INSTALLATION" = "" ] ; then
    echo "Failed to set GCC_INSTALLATION for stdcxx build" 1>&2 && exit 1
elif [ "$STDLIB" = "libcxx" ] && [ "$CLANG_INSTALLATION" = "" ] ; then
    echo "Failed to set CLANG_INSTALLATION for libcxx build" 1>&2 && exit 1
    
elif [ "$STDLIB" = "stdcxx" ] && [ "$GCC_INSTALLATION" != "" ] ; then
    # --------------------------------------------------------------------------------------- stdcxx
    # Get the major version
    DIR="$GCC_INSTALLATION/include/c++"
    NPARTS="$(echo "$DIR" | tr '/' '\n' | wc -l)"
    CC_MAJOR_VERSION="$(find "$DIR" -maxdepth 1 -type d | grep -Ev "^$DIR\$" | awk -F/ '{ print $NF }' | sort -g | tail -n 1)"
    
    CPP_DIR="$GCC_INSTALLATION/include/c++/$CC_MAJOR_VERSION"

    CPP_INC_TRIPLE_DIR=""
    for TRIPLE in $TRIPLE_LIST ; do
        if [ -d "$CPP_DIR/$TRIPLE" ] ; then
            CPP_INC_TRIPLE_DIR="$CPP_DIR/$TRIPLE"
            break
        fi
    done
    if [ "$CPP_INC_TRIPLE_DIR" = "" ] ; then
        echo "Failed to find $CPP_DIR/[$TRIPLE_LIST] directory" 1>&2 && exit 1
    fi
    
    CPP_LIB_TRIPLE_DIR=""
    for TRIPLE in $TRIPLE_LIST ; do
        if [ -d "$CPP_DIR/$TRIPLE" ] ; then
            CPP_LIB_TRIPLE_DIR="$GCC_INSTALLATION/lib/gcc/$TRIPLE/$CC_MAJOR_VERSION"
            break
        fi
    done
    if [ "$CPP_LIB_TRIPLE_DIR" = "" ] ; then
        echo "Failed to find $GCC_INSTALLATION/lib/gcc/[$TRIPLE_LIST]/$CC_MAJOR_VERSION directory" 1>&2 && exit 1
    fi    

    CXXLIB_FLAGS="-nostdinc++ -isystem$CPP_DIR -isystem$CPP_INC_TRIPLE_DIR"
    CXXLIB_LDFLAGS=""
    CXXLIB_LIBS="-L$GCC_INSTALLATION/lib64 -Wl,-rpath,$GCC_INSTALLATION/lib64 -L$CPP_LIB_TRIPLE_DIR -Wl,-rpath,$CPP_LIB_TRIPLE_DIR -lstdc++"

elif [ "$STDLIB" = "libcxx" ] && [ "$CLANG_INSTALLATION" != "" ] ; then
    # --------------------------------------------------------------------------------------- libcxx
    TRIPLE=""
    for TEST_TRIPLE in $TRIPLE_LIST ; do
        if [ -d "$CLANG_INSTALLATION/include/$TEST_TRIPLE/c++/v1" ] ; then
            TRIPLE="$TEST_TRIPLE"
            break
        fi
    done
    if [ "$TRIPLE" = "" ] ; then
        echo "Failed to find libcxx directory $CLANG_INSTALLATION/include/[$TRIPLE_LIST]/c++/v1" 1>&2
        exit 1
    fi
    
    PLATFORM_INC_DIR="$CLANG_INSTALLATION/include/$TRIPLE/c++/v1"
    CPPINC_DIR="$CLANG_INSTALLATION/include"
    CPPLIB_DIR="$CLANG_INSTALLATION/lib/$TRIPLE"
    if [ ! -d "$PLATFORM_INC_DIR" ] ; then
        echo "libcxx c++ directory not found: '$PLATFORM_INC_DIR'" 1>&2 && exit 1
    fi
    if [ ! -d "$CPPLIB_DIR" ] ; then
        echo "Failed to find clang libc++ directory: '$CPPLIB_DIR'" 1>&2 && exit 1
    fi

    CXXLIB_FLAGS="-nostdinc++ -isystem$CPPINC_DIR/c++/v1 -isystem$CPPINC_DIR -isystem$PLATFORM_INC_DIR"
    if [ "$TOOL" = "gcc" ] ; then
        CXXLIB_LDFLAGS="-nodefaultlibs"
        CXXLIB_LIBS="-L$CPPLIB_DIR -lc++ -lc++abi -Wl,-rpath,$CPPLIB_DIR -lpthread -lc -lm -lgcc_s -static-libgcc -lgcc -L/lib64 -l:ld-linux-x86-64.so.2"
    else
        CXXLIB_LDFLAGS="-nostdlib++"
        CXXLIB_LIBS="-L$CPPLIB_DIR -lc++ -lc++abi -Wl,-rpath,$CPPLIB_DIR -lpthread"
    fi    
fi

# -------------------------------------------------------------------------------------- End Actions

print_variables()
{
    cat <<EOF
# Directories
export OPERATING_SYSTEM=$OPERATING_SYSTEM
export TRIPLE_LIST="$TRIPLE_LIST"
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH
export TOOLCHAIN_ROOT=$TOOLCHAIN_ROOT
export GCC_INSTALLATION=$GCC_INSTALLATION
export CLANG_INSTALLATION=$CLANG_INSTALLATION
export PREFIX=$PREFIX
export BUILDDIR=$BUILDDIR

# Important files
export MAKE_ENV_INC_FILE=$MAKE_ENV_INC_FILE

# Compiler information
export TOOL=$TOOL
export MAJOR_VERSION=$MAJOR_VERSION

# Binaries
export CC=$CC
export CXX=$CXX
export AR=$AR
export NM=$NM
export RANLIB=$RANLIB
export GCOV=$GCOV
export LLD=$LLD

# build variables
export CXXLIB_FLAGS="$CXXLIB_FLAGS"
export CXXLIB_LDFLAGS="$CXXLIB_LDFLAGS"
export CXXLIB_LIBS="$CXXLIB_LIBS"

EOF
}

[ "$PRINT" = "True" ] && print_variables || true
if [ "$WRITE_MAKE_ENV_INC" = "True" ] ; then
    mkdir -p "$BUILDDIR"
    print_variables | sed 's,=,:=,' | sed 's,^export ,,' > $MAKE_ENV_INC_FILE
fi

eval $(print_variables)

