#!/usr/bin/env bash

set -e
set -o xtrace

RUN_DIR=${RUN_DIR:-"run"}
TIMEOUT=${TIMEOUT:-"30m"}

: "${PACKAGES_SRC_DIR:?Not set}"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <parallel opts>"
    exit 1
fi

TASK_NAME=$(basename "${1%.*}")
: "${TASK_NAME:?Not set}"
: "${LIB_DIR:?Not set}"

[ -d "$RUN_DIR" ] || mkdir -p "$RUN_DIR"

OUTPUT_DIR=$RUN_DIR/$TASK_NAME

[ -d "$OUTPUT_DIR" ] || mkdir -p "$OUTPUT_DIR"

cmd="$(realpath $1)"
shift 1

if [ -z "$PACKAGES" ]; then
    pkg_listing_cmd="find $PACKAGES_SRC_DIR/ -mindepth 1 -maxdepth 1 -type d"
elif [ -f "$PACKAGES" ]; then
    pkg_listing_cmd="cat $PACKAGES | sed -e 's|^|$PACKAGES_SRC_DIR/|'"
else
    pkg_listing_cmd="echo $PACKAGES | tr , '\n' | sed -e 's|^|$PACKAGES_SRC_DIR/|'"
fi

export R_LIBS="$LIB_DIR"

eval "$pkg_listing_cmd" | \
    parallel \
    --bar \
    --files \
    --workdir "$OUTPUT_DIR/{/}/" \
    --tagstring "$TASK_NAME - {/}" \
    --result "$OUTPUT_DIR/{/}/" \
    --joblog "$OUTPUT_DIR/parallel.log" \
    --timeout $TIMEOUT \
    "$cmd" "$PACKAGES_SRC_DIR/{/}" "$@"
