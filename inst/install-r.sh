#!/usr/bin/env bash

set -e
set -o xtrace

CFLAGS=${CFLAGS:-""}
CONFIGURE_OPTS=${CONFIGURE_OPTS:-""}
MAKE_OPTS=${MAKE_OPTS:-"-j"}

: "${CRAN_MIRROR_URL:?Not set}"
: "${R_PROJECT_BASE_DIR:?Not set}"
: "${R_VERSION_FULL:?Not set}"

pushd . > /dev/null

DEST_DIR="$R_PROJECT_BASE_DIR/R"

[ -d "$DEST_DIR" ] || mkdir -p "$DEST_DIR"

cd "$R_PROJECT_BASE_DIR/R"
curl "$CRAN_MIRROR_URL/src/base/R-${R_VERSION_FULL:0:1}/R-$R_VERSION_FULL.tar.gz" | tar -xzf -

cd "R-$R_VERSION_FULL"

export CPPFLAGS="-g3 -O2 -ggdb3"
export CFLAGS="-g3 -O2 -ggdb3"
export R_KEEP_PKG_SOURCE=yes
export CXX="g++"

./configure --prefix="$DEST_DIR/R-$R_VERSION_FULL" \
    --with-blas --with-lapack --without-ICU --with-x \
    --with-tcltk --without-aqua --with-recommended-packages \
    --without-internal-tzcode --with-included-gettext \
    --disable-byte-compiled-packages \
    "$CONFIGURE_OPTS"

make "$MAKE_OPTS"
make "$MAKE_OPTS" install

popd
