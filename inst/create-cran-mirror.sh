#!/usr/bin/env bash

set -e
set -o xtrace

: "${CRAN_MIRROR_HOST:?Not set}"
: "${CRAN_MIRROR_DIR:?Not set}"

[ -d "$CRAN_MIRROR_DIR" ] || mkdir -p "$CRAN_MIRROR_DIR"
[ -d "$CRAN_MIRROR_DIR/src" ] || mkdir -p "$CRAN_MIRROR_DIR/src"

rsync \
  -rtlzv \
  --delete \
  --include='*.tar.gz' \
  --include='PACKAGES*' \
  --exclude='*/*' \
  "${CRAN_MIRROR_HOST}::CRAN/src/contrib" "$CRAN_MIRROR_DIR/src"
