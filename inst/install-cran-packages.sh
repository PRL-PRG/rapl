#!/usr/bin/env bash

set -e
set -o xtrace

: "${LIB_DIR:?Not set}"
: "${R_BIN_DIR:?Not set}"

export R_LIBS=$LIB_DIR

BASE_DIR=$(dirname $(readlink -f $0))

"$R_BIN_DIR/Rscript" "$BASE_DIR/install-cran-packages.R" "$@"
