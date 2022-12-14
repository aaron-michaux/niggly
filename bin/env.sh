
# ------------------------------------------------------ Host Platform Variables
export TOOLS_DIR=/opt/tools
export TOOLCHAINS_DIR=/opt/toolchains
export ARCH_DIR=/opt/arch

# Tool (host) compilers
export HOST_CC=/usr/bin/gcc
export HOST_CXX=/usr/bin/g++
export LINKER=/usr/bin/ld

export PYTHON_VERSION="$(python3 --version | awk '{print $2}' | sed 's,.[0-9]$,,')"

export CLEANUP="True"

# These dependencies need to be made, and are then used globally
export CMAKE="$TOOLS_DIR/bin/cmake"
export DEFAULT_LLVM_VERSION="clang-15.0.6"
export DEFAULT_GCC_VERSION="gcc-12.2.0"

# --------------------------------------------------------------------- Platform
export IS_UBUNTU=$([ -x /usr/bin/lsb_release ] && lsb_release -a 2>/dev/null | grep -q Ubuntu && echo "True" || echo "False")
export IS_FEDORA=$([ -f /etc/fedora-release ] && echo "True" || echo "False")
export IS_OSX=$([ "$(uname -s)" = "Darwin" ] && echo "True" || echo "False")

show_help_snippet()
{
    cat <<EOF
      --version=<version>    The version of the tool/library to build

      --cleanup              Remove temporary files after building
      --no-cleanup           Do not remove temporary files after building

      --with-gcc=<version>   Use this GCC version, for stdcxx, or the full toolchain
      --with-clang=<version> Use this Clang/LLVM version, for libcxx, or the full toolchain
      --toolchain=<value>    Could be "clang" or "gcc", or the full version, eg. gcc-12.2.0

      --libcxx               Build with clang's libcxx
      --stdcxx               Build with gcc's libstdcxx

      --force                Force reinstall of target
      --env                  Print script environment variables
EOF
}

ensure_link()
{
    local SOURCE="$1"
    local DEST="$2"

    if [ ! -e "$SOURCE" ] ; then echo "File/directory not found '$SOURCE'" ; exit 1 ; fi
    sudo mkdir -p "$(dirname "$DEST")"
    sudo rm -f "$DEST"
    sudo ln -s "$SOURCE" "$DEST"
}

is_group()
{
    local GROUP="$1"
    cat /etc/group | grep -qE "^${GROUP}:" && return 0 || return 1
}

ensure_directory()
{
    local D="$1"
    if [ ! -d "$D" ] ; then
        echo "Directory '$D' does not exist, creating..."
        sudo mkdir -p "$D"
    fi
    if [ ! -w "$D" ] ; then
        echo "Directory '$D' is not writable by $USER, chgrp..."
        is_group staff && sudo chgrp -R staff "$D" || true
        is_group adm   && sudo chgrp -R adm   "$D" || true
        sudo chmod 775 "$D"
    fi
    if [ ! -d "$D" ] || [ ! -w "$D" ] ; then
        echo "Failed to ensure writable directory '$D', should you run as root?"
        exit 1
    fi
}

ensure_llvm_dir()
{
    if [ ! -d "$LLVM_DIR" ] ; then
        echo "Failed to find llvm installation at '$LLVM_DIR', did you forget to build llvm?" 1>&2
        exit 1
    fi
}

install_dependences()
{
    # If compiling for a different platforms, we'd augment this files with
    # brew commands (macos), yum (fedora) etc.
    if [ "$IS_UBUNTU" = "True" ] ; then
        export DEBIAN_FRONTEND=noninteractive
        sudo apt-get install -y -qq \
             wget subversion automake swig python2.7-dev libedit-dev libncurses5-dev  \
             python3-dev python3-pip python3-tk python3-lxml python3-six              \
             libparted-dev flex sphinx-doc guile-2.2 gperf gettext expect tcl dejagnu \
             libgmp-dev libmpfr-dev libmpc-dev patchelf liblz-dev pax-utils 

    elif [ "$IS_OSX" = "True" ] ; then
        which nproc 1>/dev/null || brew install coreutils
        
    fi
}

ensure_toolchain_is_valid()
{
    local TOOLCHAIN="$1"
    local TOOLCHAIN_ROOT="$TOOLCHAINS_DIR/$TOOLCHAIN"

    if [ "$TOOLCHAIN" = "" ] ; then
        echo "Toolchain not specified" 1>&2
        exit 1
        
    elif [ ! -d "$TOOLCHAIN_ROOT" ] ; then
        echo "Toolchain not found: '$TOOLCHAIN_ROOT'" 1>&2
        exit 1
    fi
}

list_toolchains()
{
    if [ -d "$TOOLCHAINS_DIR" ] ; then
        ls "$TOOLCHAINS_DIR" | sort
    fi
}

setup_stdcxx()
{
    local TOOLCHAIN="$1"
    local TRIPLE_LIST="$2"
    local TOOLCHAIN_ROOT="$TOOLCHAINS_DIR/$TOOLCHAIN"
    local CC_MAJOR_VERSION="$(echo ${TOOLCHAIN:4} | awk -F. '{ print $1 }')"
    local CPP_DIR="$TOOLCHAIN_ROOT/include/c++/$CC_MAJOR_VERSION"
   
    if [ "${TOOLCHAIN:0:3}" != "gcc" ] ; then
        echo "Must specify a gcc toolchain to find libstdcxx!" 1>&2 && exit 1
    fi
    
    CXXFLAGS+=" -isystem$CPP_DIR"
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
    CXXFLAGS+=" -isystem$CPP_INC_TRIPLE_DIR"
    
    ADDITIONAL_LDFLAGS="-L$TOOLCHAIN_ROOT/lib64 -Wl,-rpath,$TOOLCHAIN_ROOT/lib64"
    
    CPP_LIB_TRIPLE_DIR=""
    for TRIPLE in $TRIPLE_LIST ; do
        if [ -d "$CPP_DIR/$TRIPLE" ] ; then
            CPP_LIB_TRIPLE_DIR="$TOOLCHAIN_ROOT/lib/gcc/$TRIPLE/$CC_MAJOR_VERSION"
            break
        fi
    done
    if [ "$CPP_LIB_TRIPLE_DIR" = "" ] ; then
        echo "Failed to find $TOOLCHAIN_ROOT/lib/gcc/[$TRIPLE_LIST]/$CC_MAJOR_VERSION directory" 1>&2 && exit 1
    fi
    ADDITIONAL_LDFLAGS+=" -L$CPP_LIB_TRIPLE_DIR -Wl,-rpath,$CPP_LIB_TRIPLE_DIR"
    
    if [ "$IS_GCC" = "True" ] ; then
        CXXFLAGS="-nostdinc++ $CXXFLAGS"
    fi
    
    export CXXFLAGS="$CXXFLAGS"
    export LDFLAGS="$ADDITIONAL_LDFLAGS $LDFLAGS -lstdc++"    
}


setup_libcxx()
{
    local TOOLCHAIN="$1"
    local TRIPLE_LIST="$2"
    TOOLCHAIN_ROOT="$TOOLCHAINS_DIR/$TOOLCHAIN"

    if [ "${TOOLCHAIN:0:5}" != "clang" ] ; then
        echo "Must specify a clang toolchain to find libcxx!" 1>&2 && exit 1
    fi

    TRIPLE=""
    for TEST_TRIPLE in $TRIPLE_LIST ; do
        if [ -d "$TOOLCHAIN_ROOT/include/$TEST_TRIPLE/c++/v1" ] ; then
            TRIPLE="$TEST_TRIPLE"
            break
        fi
    done
    if [ "$TRIPLE" = "" ] ; then
        echo "Failed to find libcxx directory $TOOLCHAIN_ROOT/include/$TRIPLE/c++/v1" 1>&2
        exit 1
    fi
    
    PLATFORM_INC_DIR="$TOOLCHAIN_ROOT/include/$TRIPLE/c++/v1"
    CPPINC_DIR="$TOOLCHAIN_ROOT/include"
    CPPLIB_DIR="$TOOLCHAIN_ROOT/lib/$TRIPLE"

    if [ ! -d "$PLATFORM_INC_DIR" ] ; then
        echo "libcxx c++ directory not found: '$PLATFORM_INC_DIR'" 1>&2 && exit 1
    fi
    if [ ! -d "$CPPLIB_DIR" ] ; then
        echo "Failed to find clang libc++ directory: '$CPPLIB_DIR'" 1>&2 && exit 1
    fi
    
    EXTRA_CXXFLAGS="-isystem$CPPINC_DIR/c++/v1 -isystem$CPPINC_DIR -isystem$PLATFORM_INC_DIR"
    START_LDFLAGS=""
    END_LDFLAGS="-L$CPPLIB_DIR -lc++ -lc++abi -Wl,-rpath,$CPPLIB_DIR -lpthread"

    if [ "$IS_GCC" = "True" ] ; then
        EXTRA_CXXFLAGS="-nostdinc++ $EXTRA_CXXFLAGS"
        export LDFLAGS="-nodefaultlibs $LDFLAGS $END_LDFLAGS -lc -lm -lgcc_s -static-libgcc -lgcc -L/lib64 -l:ld-linux-x86-64.so.2"

    else
        EXTRA_CXXFLAGS="-nostdinc++ $EXTRA_CXXFLAGS"
        export LDFLAGS="-nostdlib++ $LDFLAGS $END_LDFLAGS"
    fi
    
    export CXXFLAGS="$EXTRA_CXXFLAGS $CXXFLAGS"
}

major_version()
{
    local TOOLCHAIN="$1"
    if [ "${TOOLCHAIN:0:3}" = "gcc" ] ; then
        echo ${TOOLCHAIN:4} | awk -F. '{ print $1 }'
    elif [ "$TOOLCHAIN:0:5}" = "clang" ] ; then
        echo ${TOOLCHAIN:6} | awk -F. '{ print $1 }'
    else
        echo "unsupported toolchain: '$TOOLCHAIN'" 1>&2 && exit 1
    fi
}

crosstool_setup()
{
    # So, TOOLCHAIN could be gcc-12.2.0, but ALT_TOOLCHAIN would be clang-15.0.6
    # In this case, we use gcc, but lld, libcxx, is found under 'clang-15.0.6'

    local TOOLCHAIN="$1"
    local GCC_TOOLCHAIN="$2"
    local LLVM_TOOLCHAIN="$3"
    local STDLIB="$4"

    if [ "$TOOLCHAIN" = "gcc" ] ; then
        export TOOLCHAIN="$GCC_TOOLCHAIN"
    elif [ "$TOOLCHAIN" = "clang" ] || [ "$TOOLCHAIN" = "llvm" ] ; then
        export TOOLCHAIN="$LLVM_TOOLCHAIN"        
    fi

    ensure_toolchain_is_valid "$TOOLCHAIN"

    export GCC_DIR="$TOOLCHAINS_DIR/$GCC_TOOLCHAIN"
    export LLVM_DIR="$TOOLCHAINS_DIR/$LLVM_TOOLCHAIN"

    export PYTHON_FULL_VERSION=$(python3 --version)
    export PYTHON_VERSION="3.$(echo "$PYTHON_FULL_VERSION" | awk -F. '{ print $2 }')"
    
    if [ "${TOOLCHAIN:0:3}" = "gcc" ] ; then
        export IS_GCC="True"
        export IS_LLVM="False"
        export CC_MAJOR_VERSION="$(echo ${TOOLCHAIN:4} | awk -F. '{ print $1 }')"
        export GCC_TOOLCHAIN="$TOOLCHAIN"
        export TOOLCHAIN_VERSION="$(echo ${TOOLCHAIN:4} | awk -F. '{ print $1 }')"
        export CXXSTD="c++23"
    else
        export IS_GCC="False"
        export IS_LLVM="True"
        export CC_MAJOR_VERSION="$(echo ${TOOLCHAIN:6} | awk -F. '{ print $1 }')"
        export LLVM_TOOLCHAIN="$TOOLCHAIN"
        export TOOLCHAIN_VERSION="$(echo ${TOOLCHAIN:6} | awk -F. '{ print $1 }')"
        export CXXSTD="c++2b"
    fi
    
    export TRIPLE_LIST="$(uname -m)-linux-gnu $(uname -m)-pc-linux-gnu $(uname -m)-unknown-linux-gnu"
    
    if [ "$IS_OSX" = "True" ] ; then
        echo "Unimplemented" 1>&2 && exit 1
        # if [ "$(uname -m)" = "arm64" ] ; then
        #     export ARCH="aarch64-apple-darwin$(uname -r | awk -F. '{print $1}')"
        # elif [ "$(uname -m)" = "x86_64" ] ; then
        #     export ARCH="x86_64-apple-darwin$(uname -r | awk -F. '{print $1}')"
        # else
        #     echo "unsupported arch $(uname -m), aborting" 1>&2 && exit 1
        # fi
    fi

    export TOOLCHAIN_ROOT="$TOOLCHAINS_DIR/$TOOLCHAIN"
   
    if [ "$IS_GCC" = "True" ] ; then
        export TOOLCHAIN_NAME="gcc"
        export CC="$TOOLCHAIN_ROOT/bin/gcc-$CC_MAJOR_VERSION"
        export CXX="$TOOLCHAIN_ROOT/bin/g++-$CC_MAJOR_VERSION"
        export AR="$TOOLCHAIN_ROOT/bin/gcc-ar-$CC_MAJOR_VERSION"
        export NM="$TOOLCHAIN_ROOT/bin/gcc-nm-$CC_MAJOR_VERSION"
        export RANLIB="$TOOLCHAIN_ROOT/bin/gcc-ranlib-$CC_MAJOR_VERSION"
        export GCOV="$TOOLCHAIN_ROOT/bin/gcov-$CC_MAJOR_VERSION"
        export LLD="$LLVM_DIR/bin/ld.lld"
 
    elif [ "$IS_LLVM" = "True" ] ; then
        export TOOLCHAIN_NAME="clang"
        export CC="$TOOLCHAIN_ROOT/bin/clang"
        export CXX="$TOOLCHAIN_ROOT/bin/clang++"
        export AR="$TOOLCHAIN_ROOT/bin/llvm-ar"
        export NM="$TOOLCHAIN_ROOT/bin/llvm-nm"
        export RANLIB="$TOOLCHAIN_ROOT/bin/llvm-ranlib"
        export GCOV="$GCC_DIR/bin/gcov-$(major_version $GCC_TOOLCHAIN)"
        export LLD="$TOOLCHAIN_ROOT/bin/ld.lld"

    else
        echo "logic error" 1>&2 && exit 1
    fi

    export TRIPLE="$(echo "$TRIPLE_LIST" | awk '{ print $1 }')"
    export PREFIX="$ARCH_DIR/${TRIPLE}_${TOOLCHAIN}_${STDLIB}"
    export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

    export CFLAGS="-fPIC -O3 -isystem$PREFIX/include"
    export CXXFLAGS="-fPIC -O3 -isystem$PREFIX/include"
    [ "$IS_LLVM" = "True" ] && LDFLAGS="-fuse-ld=lld " || LD_FLAGS=""
    LDFLAGS+="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
    export LDFLAGS="$LDFLAGS"
    export LIBS="-lm -pthreads"   
    
    export STDLIB="$STDLIB"
    if [ "$STDLIB" = "stdcxx" ] ; then
        ensure_toolchain_is_valid "$GCC_TOOLCHAIN"        
        setup_stdcxx "$GCC_TOOLCHAIN" "$TRIPLE_LIST"
    else
        ensure_toolchain_is_valid "$LLVM_TOOLCHAIN"        
        setup_libcxx "$LLVM_TOOLCHAIN" "$TRIPLE_LIST"
    fi

    LIBRARY_SEARCH_PATHS="$($CXX -print-search-dirs | grep -E '^libraries' | sed 's,^libraries: =,,' | tr ':' '\n' | sed 's,/$,,')"
    
    [ ! -x "$CC" ] && echo "Failed to find CC=$CC" 1>&2 && exit 1 || true
    [ ! -x "$CXX" ] && echo "Failed to find CXX=$CXX" 1>&2 && exit 1 || true
    [ ! -x "$AR" ] && echo "Failed to find AR=$AR" 1>&2 && exit 1 || true
    [ ! -x "$NM" ] && echo "Failed to find NM=$NM" 1>&2 && exit 1 || true
    [ ! -x "$RANLIB" ] && echo "Failed to find RANLIB=$RANLIB" 1>&2 && exit 1 || true
}

print_env()
{
    cat <<EOF

    IS_UBUNTU:       $IS_UBUNTU
    IS_FEDORA:       $IS_FEDORA
    IS_OSX:          $IS_OSX

    GCC_VERSION:     $GCC_VERSION
    LLVM_VERSION:    $LLVM_VERSION
    STDLIB:          $STDLIB
    TRIPLE:          $TRIPLE

    PREFIX:          $PREFIX
    PKG_CONFIG_PATH: $PKG_CONFIG_PATH

    CC:              $CC
    CXX:             $CXX
    AR:              $AR
    NM:              $NM
    RANLIB:          $RANLIB
    GCOV:            $GCOV
    LLD:             $LLD

    CXXSTD           $CXXSTD
    CFLAGS:          $CFLAGS
    CXXFLAGS:        $CXXFLAGS

    LDFLAGS:         $LDFLAGS
    LIBS:            $LIBS

    AVAILABLE TOOLCHAINS:      
$(list_toolchains | sed 's,^,        ,')

EOF
}

# ---------------------------------------------------------------------- cleanup

cleanup()
{
    if [ "$CLEANUP" = "True" ] ; then
        if [ -f "$TMPD/user-config.jam" ] ; then
            mv "$TMPD/user-config.jam" $HOME/
        else
            rm -f "$HOME/user-config.jam"
        fi
        rm -rf "$TMPD"
    fi
}

make_working_dir()
{
    local SCRIPT_NAME="$1"

    if [ "$CLEANUP" = "True" ] ; then
        TMPD="$(mktemp -d /tmp/$(basename "$SCRIPT_NAME" .sh).XXXXXX)"
    else
        TMPD="/tmp/$(basename "$SCRIPT_NAME" .sh)-${USER}"
    fi
    if [ "$CLEANUP" = "False" ] ; then
        mkdir -p "$TMPD"
    fi

    trap cleanup EXIT
}

# ------------------------------------------------------------- parse basic args

parse_basic_args()
{
    local SCRIPT_NAME="$(echo "$1" | sed 's,^./,,')"
    shift
    local REQUIRE_TOOLCHAIN="$1"
    shift
    
    (( $# == 0 )) && show_help && exit 0 || true
    for ARG in "$@" ; do
        [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
    done

    CLEANUP="True"
    VERSION=""
    TOOLCHAIN=""
    PRINT_ENV="False"
    STDLIB="stdcxx"
    GCC_VERSION="$DEFAULT_GCC_VERSION"
    LLVM_VERSION="$DEFAULT_LLVM_VERSION"
    export FORCE_INSTALL="False"
    
    while (( $# > 0 )) ; do
        ARG="$1"
        shift

        LHS=$(echo "$ARG" | awk -F= '{ print $1 }')
        RHS=$(echo "$ARG" | awk -F= '{ print $2 }')
        
        [ "$ARG" = "--cleanup" ]       && export CLEANUP="True" && continue
        [ "$ARG" = "--no-cleanup" ]    && export CLEANUP="False" && continue
        [ "$ARG" = "--libcxx" ]        && export STDLIB="libcxx" && continue
        [ "$ARG" = "--stdcxx" ]        && export STDLIB="stdcxx" && continue

        [ "$LHS" = "--with-gcc=" ]     && export GCC_VERSION="gcc-$RHS" && continue
        [ "$LHS" = "--with-llvm=" ]    && export LLVM_VERSION="clang-$RHS" && continue

        [ "$ARG" = "--toolchain" ]     && export TOOLCHAIN="$1" && shift && continue
        [ "$LHS" = "--toolchain" ]     && export TOOLCHAIN="$RHS" && continue

        [ "$ARG" = "--force" ] || [ "$ARG" = "-f" ] && export FORCE_INSTALL="True" && continue

        [ "$ARG" = "--env" ]           && PRINT_ENV="True" && continue

        [ "$LHS" = "--version" ]       && export VERSION="$RHS" && continue
        [ "$ARG" = "--version" ]       && export VERSION="$1" && shift && continue

        echo "unexpected argument: '$ARG'" 1>&2 && exit 1
    done

    if [ "$TOOLCHAIN" = "" ] ; then
        if [ "$REQUIRE_TOOLCHAIN" = "True" ] || [ "$REQUIRE_TOOLCHAIN" = "UseToolchain" ]; then
            echo "Must specify a toolchain!" 1>&2
            exit 1
        fi        
    else
        crosstool_setup "$TOOLCHAIN" "$GCC_VERSION" "$LLVM_VERSION" "$STDLIB"
    fi

    if [ "$PRINT_ENV" = "True" ] ; then
        print_env
        exit 0
    fi

    if [ "$VERSION" = "" ] ; then
        VERSION_FILE="$(dirname "$0")/versions.text"
        if [ ! -f "$VERSION_FILE" ] ; then
            echo "Failed to find versions file!" 1>&2 && exit 1
        fi
        export VERSION="$(cat "$VERSION_FILE" | grep "$SCRIPT_NAME" | awk '{ print $2 }')"
        if [ "$VERSION" = "" ] ; then
            echo "Script $SCRIPT_NAME does not appear in '$VERSION_FILE', and version not specified on the command line, aborting" 1>&2 && exit 1
        fi
    fi
    
    make_working_dir "$SCRIPT_NAME"
}


