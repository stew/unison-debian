#!/bin/sh

set -ex

usage() {
    echo "Usage: $0 version tag \n\
\n\
Example: $0 0.0.1~M1j release/M1j\n\
"
exit 1
}

if [ $# -ne 2 ]; then
    usage
fi

version=$1 ; shift
release=$1 ; shift

tmpdir=$(mktemp -d)

git clone --recursive -b ${release} https://github.com/unisonweb/unison $tmpdir/unison

tar -C ${tmpdir} --exclude .git -czf unison_${version}.orig.tar.gz unison

rm -rf $tmpdir
