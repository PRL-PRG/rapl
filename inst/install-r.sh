#!/usr/bin/env bash

set -e
set -o xtrace

CFLAGS=${CFLAGS:-""}
CONFIGURE_OPTS=${CONFIGURE_OPTS:-""}
MAKE_OPTS=${MAKE_OPTS:-"-j70"}

: "${CRAN_MIRROR_URL:?Not set}"
: "${R_PROJECT_BASE_DIR:?Not set}"
: "${R_VERSION_FULL:?Not set}"

pushd . > /dev/null

DEST_DIR="$R_PROJECT_BASE_DIR/R"

[ -d "$DEST_DIR" ] || mkdir -p "$DEST_DIR"

cd "$R_PROJECT_BASE_DIR/R"
curl "$CRAN_MIRROR_URL/src/base/R-3/R-$R_VERSION_FULL.tar.gz" | tar -xzf -

cd "R-$R_VERSION_FULL"
./configure --prefix="$DEST_DIR/R-$R_VERSION_FULL" "$CONFIGURE_OPTS"
make "$MAKE_OPTS"
make "$MAKE_OPTS" install

popd
