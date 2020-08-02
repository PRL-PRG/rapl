#!/usr/bin/env bash

set -e

CFLAGS=${CFLAGS:-""}
CONFIGURE_OPTS=${CONFIGURE_OPTS:-""}
CRAN_MIRROR_URL=${CRAN_MIRROR_URL:-"https://cloud.r-project.org"}
MAKE_OPTS=${MAKE_OPTS:-"-j"}

def_dest=${R_BASE_DIR:-"."}
def_version=${R_VERSION_FULL:-"4.0.2"}
def_source="$CRAN_MIRROR_URL/src/base/R-${def_version:0:1}/R-$def_version.tar.gz"

function show_help() {
    echo "Usage: $(basename $0) [-d PATH] [-s URL ] [-v VERSION]"
    echo
    echo "where:"
    echo
    echo "  -d PATH      to install R to (defaults to $def_dest)"
    echo "  -s URL       to get R from (defaults to $def_source)"
    echo "  -v VERSION   of R to install (defaults to $def_version)"
    echo
}

dest=$def_dest
source=$def_source
version=$def_version

while getopts "h?d:s:v:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    d)  dest=$OPTARG
        ;;
    s)  source=$OPTARG
        ;;
    v)  version=$OPTARG
        ;;
    esac
done

echo "Installing R $version from $source into $dest"

set -o xtrace

pushd . > /dev/null

[ -d "$dest" ] || mkdir -p "$dest"
dest="$(realpath "$dest")"

cd "$dest"

curl -fsSL $source | tar --strip 1 -xzf -

export CPPFLAGS="-g3 -O2 -ggdb3"
export CFLAGS="-g3 -O2 -ggdb3"
export R_KEEP_PKG_SOURCE=yes
export CXX="g++"

./configure --prefix="$dest/R-$version" \
    --with-blas --with-lapack --without-ICU --with-x \
    --with-tcltk --without-aqua --with-recommended-packages \
    --without-internal-tzcode --with-included-gettext \
    --disable-byte-compiled-packages \
    "$CONFIGURE_OPTS"

make "$MAKE_OPTS"
make "$MAKE_OPTS" install
make "$MAKE_OPTS" install-tests

popd
