#!/bin/bash

set -e

show_help()
{
    cat <<EOF

   Usage: $(basename $0)

   Checks libcxx installations for any stray erroneous linking to libstdc++

EOF
}

WORKING_DIR="$(cd "$(dirname "$0")" ; pwd)"
cd "$WORKING_DIR"
source "./env/platform-env.sh"

TMPD="$(mktemp -d $(basename "$0").XXXXXX)"
trap check_cleanup EXIT
check_cleanup()
{
    rm -rf "$TMPD"
}

find_installations()
{
    find "$ARCH_DIR" -maxdepth 1 -type d -name '*_libcxx' | sort
}

check_installation()
{
    echo "0" > $TMPD/1
    find -L "$DIR" -type l -o -type f -name '*.so' | while read FILE ; do
        lddtree "$FILE" | grep -q "libstdc++" && SUCCESS="False" || SUCCESS="True"
        if [ "$SUCCESS" = "False" ] ; then
            echo "Error: $FILE links to libstdc++"
            echo "1" > $TMPD/1
        fi
    done
    return "$(cat "$TMPD/1")"
}

echo "0" > $TMPD/exit-code
find_installations | while read DIR ; do    
    if check_installation "$DIR" ; then
        echo "PASS: $DIR"
    else
        echo "1" > $TMPD/exit-code
    fi
done

exit "$(cat $TMPD/exit-code)"

