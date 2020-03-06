#!/usr/bin/env bash

set -ex

: "${R_BIN:?Not set}"
: "${CRAN_MIRROR_DIR:?Not set}"
: "${PACKAGES_SRC_DIR:?Not set}"
: "${LIB_DIR:?Not set}"

echo "Extracting from $CRAN_MIRROR_DIR into $PACKAGES_SRC_DIR (installed packages in $LIB_DIR)"

$R_BIN --slave -e "x <- installed.packages(lib.loc='$LIB_DIR'); cat(paste0(x[,1], '_', x[,3], '.tar.gz', collapse='\n'))" | \
  parallel --workdir "$PACKAGES_SRC_DIR" --bar tar xzf "$CRAN_MIRROR_DIR/src/contrib/{}"
