#!/usr/bin/env bash

set -ex

: "${CRAN_MIRROR_DIR:?Not set}"
: "${PACKAGES_SRC_DIR:?Not set}"

echo "Extracting from $CRAN_MIRROR_DIR into $PACKAGES_SRC_DIR"

find "$CRAN_MIRROR_DIR/src/contrib" -name '*.tar.gz' | \
  parallel --workdir "$PACKAGES_SRC_DIR" --bar tar xzf "{}"
