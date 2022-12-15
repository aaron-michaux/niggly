
# ------------------------------------------------------ Host Platform Variables

source "$(dirname "$BASH_SOURCE")/platform-env.sh"

export GCC_CXXSTD=c++23
export LLVM_CXXSTD=c++2a

export CLEANUP="True"

# --------------------------------------------------------------------- Platform

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
    if [ "$PLATFORM" = "ubuntu" ] ; then
        export DEBIAN_FRONTEND=noninteractive
        sudo apt-get install -y -qq \
             wget subversion automake swig python2.7-dev libedit-dev libncurses5-dev  \
             gcc-multilib python3-dev python3-pip python3-tk python3-lxml python3-six \
             libparted-dev flex sphinx-doc guile-2.2 gperf gettext expect tcl dejagnu \
             libgmp-dev libmpfr-dev libmpc-dev patchelf liblz-dev pax-utils 

    elif [ "$PLATFORM" = "macos" ] ; then
        which nproc 1>/dev/null 2>/dev/null || brew install coreutils
        which gsed  1>/dev/null 2>/dev/null || brew install gnu-sed
        
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

    if [ "${TOOLCHAIN:0:3}" = "gcc" ] ; then
        export CXXSTD="$GCC_CXXSTD"
    else
        export CXXSTD="$LLVM_CXXSTD"
    fi
    
    GCC_MAJOR_VERSION="$(echo ${GCC_TOOLCHAIN:4} | awk -F. '{ print $1 }')"

    export GCC_DIR="$TOOLCHAINS_DIR/$GCC_TOOLCHAIN"
    export LLVM_DIR="$TOOLCHAINS_DIR/$LLVM_TOOLCHAIN"

    source "$(dirname "$BASH_SOURCE")/toolchain-env.sh"   \
        --gcc-suffix="-${GCC_MAJOR_VERSION}" \
        --gcc-installation="$GCC_DIR"        \
        --clang-installation="$LLVM_DIR"     \
        --stdlib="$STDLIB"                   \
        --toolchain="$([ "${TOOLCHAIN:0:3}" = "gcc" ] && echo "gcc" || echo "clang")"
    
    export TRIPLE="$(echo "$TRIPLE_LIST" | awk '{ print $1 }')"
    export PREFIX="$ARCH_DIR/${TRIPLE}_${TOOLCHAIN}_${STDLIB}"
    export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

    export CFLAGS="-fPIC -O3 -isystem$PREFIX/include"
    export CXXFLAGS="-fPIC -O3 -isystem$PREFIX/include $CXXLIB_FLAGS"
    [ "$IS_LLVM" = "True" ] && LDFLAGS="-fuse-ld=lld " || LD_FLAGS=""
    LDFLAGS+="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
    export LDFLAGS="$CXXLIB_LDFLAGS $LDFLAGS $CXXLIB_LIBS"
    export LIBS="-lm -pthreads"   
    
    export STDLIB="$STDLIB"
    
    [ ! -x "$CC" ] && echo "Failed to find CC=$CC" 1>&2 && exit 1 || true
    [ ! -x "$CXX" ] && echo "Failed to find CXX=$CXX" 1>&2 && exit 1 || true
    [ ! -x "$AR" ] && echo "Failed to find AR=$AR" 1>&2 && exit 1 || true
    [ ! -x "$NM" ] && echo "Failed to find NM=$NM" 1>&2 && exit 1 || true
    [ ! -x "$RANLIB" ] && echo "Failed to find RANLIB=$RANLIB" 1>&2 && exit 1 || true
    
    export CC="$CC"
    export CXX="$CXX"
    export AR="$AR"
    export NM="$NM"
    export RANLIB="$RANLIB"
    export LLD="$LLD"
    export GCOV="$GCOV"
    export TOOLCHAIN_VERSION="$MAJOR_VERSION"

    export PYTHON_FULL_VERSION=$(python3 --version)
    export PYTHON_VERSION="3.$(echo "$PYTHON_FULL_VERSION" | awk -F. '{ print $2 }')"
}

print_env()
{
    cat <<EOF

    PLATFORM:          $PLATFORM
    GCC_VERSION:       $GCC_VERSION
    LLVM_VERSION:      $LLVM_VERSION
    STDLIB:            $STDLIB
    TRIPLE:            $TRIPLE
    TOOLCHAIN_VERSION: $TOOLCHAIN_VERSION

    PREFIX:            $PREFIX
    PKG_CONFIG_PATH:   $PKG_CONFIG_PATH

    HOST_CC            $HOST_CC
    HOST_CXX           $HOST_CXX

    CC:                $CC
    CXX:               $CXX
    AR:                $AR
    NM:                $NM
    RANLIB:            $RANLIB
    GCOV:              $GCOV
    LLD:               $LLD

    CXXSTD             $CXXSTD
    CFLAGS:            $CFLAGS
    CXXFLAGS:          $CXXFLAGS

    LDFLAGS:           $LDFLAGS
    LIBS:              $LIBS

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

        [ "$LHS" = "--with-gcc" ]      && export GCC_VERSION="gcc-$RHS" && continue
        [ "$LHS" = "--with-llvm" ]     && export LLVM_VERSION="clang-$RHS" && continue

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
        VERSION_FILE="$(dirname "$BASH_SOURCE")/versions.text"
        if [ ! -f "$VERSION_FILE" ] ; then
            echo "Failed to find versions file!" 1>&2 && exit 1
        fi
        export VERSION="$(cat "$VERSION_FILE" | grep "$(basename $SCRIPT_NAME)" | awk '{ print $2 }')"
        if [ "$VERSION" = "" ] ; then
            echo "Script $SCRIPT_NAME does not appear in '$VERSION_FILE', and version not specified on the command line, aborting" 1>&2 && exit 1
        fi
    fi
    
    make_working_dir "$SCRIPT_NAME"
}


