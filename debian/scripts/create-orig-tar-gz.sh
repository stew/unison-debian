#!/bin/sh

set -ex

pre_flight() {
    which jq > /dev/null || (echo "this script requires jq to be installed" && exit)
}

usage() {
    echo "Usage: $0 version tag \n\
\n\
Example: $0 0.0.1~M1j release/M1j\n\
"
exit 1
}

pre_flight

if [ $# -ne 2 ]; then
    usage
fi

uriencode() { jq -nr --arg v "$1" '$v|@uri'; }

version=$1 ; shift
release=$(uriencode $1) ; shift

release_url=https://github.com/unisonweb/unison/archive/$release.tar.gz

wget -O../unisonweb-$version.orig.tar.gz $release_url
