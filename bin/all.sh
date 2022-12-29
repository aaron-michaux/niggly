#!/bin/bash

set -e

WORKING_DIR="$(cd "$(dirname "$0")" ; pwd)"
cd "$WORKING_DIR"
source "./env/platform-env.sh"
source "./env/cross-env.sh"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) [--cleanup|--no-cleanup|--force|--force-toolchain]*

   Options:

      --cleanup               Delete build files after installing
      --no-cleanup            Do no delete build files. (The default.)

      --force-libs            Force rebuilding of all libraries
      --force-tools           Force rebuilding of all tools
      --force-toolchain       Force rebuilding of toolchains

      --with-gcc=<version>    Use this GCC version, for stdcxx, or the full toolchain
      --with-clang=<version>  Use this Clang/LLVM version, for libcxx, or the full toolchain

EOF
}

TMPF=$(mktemp "/tmp/$(basename $0).XXXXXX")
trap master_cleanup EXIT
master_cleanup()
{
    rm -f "$TMPF"    
}

# ------------------------------------------------------------------------ parse

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

OPTIONS=""
FORCE_LIBS=""
FORCE_TOOLS=""
FORCE_TOOLCHAIN=""
GCC_VERSION="$DEFAULT_GCC_VERSION"
LLVM_VERSION="$DEFAULT_LLVM_VERSION"
for ARG in "$@" ; do
    LHS=$(echo "$ARG" | awk -F= '{ print $1 }')
    RHS=$(echo "$ARG" | awk -F= '{ print $2 }')

    [ "$ARG" = "--cleanup" ]         && OPTIONS="$ARG $OPTIONS"   && continue
    [ "$ARG" = "--no-cleanup" ]      && OPTIONS="$ARG $OPTIONS"   && continue
    [ "$ARG" = "--force-libs" ]      && FORCE_LIBS="--force"      && continue
    [ "$ARG" = "--force-tools" ]     && FORCE_TOOLS="--force"     && continue
    [ "$ARG" = "--force-toolchain" ] && FORCE_TOOLCHAIN="--force" && continue
    [ "$LHS" = "--with-gcc" ]        && GCC_VERSION="$RHS"        && continue
    [ "$LHS" = "--with-llvm" ]       && LLVM_VERSION="$RHS"       && continue

    echo "Unexpected argument '$ARG', aborting" 1>&2 && exit 1
done
if [ "$OPTIONS" = "" ] ; then
    # Make no-cleanup the default
    OPTIONS="--no-cleanup"
fi

# ----------------------------------------------------------------------- action

# dependencies
install_dependences

# sudo stuff
ensure_directory "$TOOLS_DIR"
ensure_directory "$TOOLCHAINS_DIR"
ensure_directory "$ARCH_DIR"

# make tools
./build-cmake.sh     $OPTIONS  $FORCE_TOOLS
./build-doxygen.sh   $OPTIONS  $FORCE_TOOLS
./build-valgrind.sh  $OPTIONS  $FORCE_TOOLS

# make toolchains
for TOOLCHAIN in "$DEFAULT_LLVM_VERSION" "$DEFAULT_GCC_VERSION" ; do    
    ./build-toolchain.sh  $OPTIONS                       \
                          $FORCE_TOOLCHAIN  "$TOOLCHAIN"
done

EXIT_CODE=0

install_library()
{
    local SCRIPT="$1"
    local SKIP="$2"
    for TOOL in "gcc" "llvm" ; do
        for STDLIB in "--libcxx" "--stdcxx" ; do
            if [ "$TOOL" = "gcc" ] && [ "$STDLIB" = "--libcxx" ] ; then
                # echo, let's not go there =)
                continue
            fi
            
            if [ "$SKIP" = "${TOOL}${STDLIB}" ] ; then
                echo "Skipping $SCRIPT for $SKIP, this combination does not build"
            else
                COMMAND="./$SCRIPT  $OPTIONS  $FORCE_LIBS  --with-gcc=$GCC_VERSION  --with-clang=$LLVM_VERSION  --toolchain=$TOOL  $STDLIB"
                $COMMAND && SUCCESS="True" || SUCCESS="False"
                if [ "$SUCCESS" = "False" ] ; then
                    echo "$COMMAND" >> $TMPF
                    EXIT_CODE=1
                fi
            fi
        done
    done            
}

install_library  build-google-benchmark.sh  
install_library  build-google-test.sh       
install_library  build-catch.sh             
install_library  build-ctre.sh              
install_library  build-expected.sh          
install_library  build-gcem.sh              
install_library  build-fmt.sh               
install_library  build-ofats.sh             
install_library  build-spdlog.sh
install_library  build-icu.sh
install_library  build-boost.sh             
install_library  build-ranges-ts.sh         
install_library  build-liburing.sh         
install_library  build-unifex.sh         
install_library  build-grpc.sh            
install_library  build-asio-grpc.sh         

if [ "$EXIT_CODE" != "0" ] ; then
    echo "Exit-Code = $EXIT_CODE, the following failed to build:"
    cat "$TMPF" | sed 's,^,   ,'
    echo
fi

echo
echo "Checking libcxx installations..."
./check-libcxx-installations.sh

exit $EXIT_CODE
