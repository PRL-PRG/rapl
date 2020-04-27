#!/usr/bin/env bash

set -e
set -o xtrace

JOBS_FILE="jobsfile.txt"
NUM_JOBS=${NUM_JOBS:-"90%"}
RUN_DIR=${RUN_DIR:-"run"}
TIMEOUT=${TIMEOUT:-"30m"}

: "${PACKAGES_SRC_DIR:?Not set}"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <script-to-run> [<args...>]"
    echo ""
    echo "Notes: "
    echo "  - <script-to-run> must be executable and take <args>+1 number of parameters"
    echo "    the first argument will be the path to the source code of a package"
    echo ""
    echo "  - Extra parameters to GNU parallel can be added by PARALLEL_ARGS env variable."
    echo "    For example, using PARALLEL_ARGS='--resume-failed' to retry failed jobs."
    echo ""
    exit 1
fi

TASK_NAME=$(basename "${1%.*}")
: "${TASK_NAME:?Not set}"
: "${LIB_DIR:?Not set}"
: "${R_BIN_DIR:?Not set}"

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

parallel_log="$OUTPUT_DIR/parallel.log"

# backup parallel log
if [ -f $parallel_log ]; then
    cnt=$(ls -1 "$parallel_log"* | wc -l)
    cnt=$(( $cnt + 1 ))
    cp "$parallel_log" "$parallel_log.$cnt"
fi

echo "$NUM_JOBS" > "$JOBS_FILE"

## assemble the environment
# set the correct lib path
export R_LIBS="$R_LIBS:$LIB_DIR"
# try to work out around too much parallelism
export OMP_NUM_THREADS=1
# prioritize the R set in the environment
export PATH="$R_BIN_DIR:$PATH"

echo "PACKAGES: $PACKAGES"
echo "PATH: $PATH"
echo "R_LIBS: $R_LIBS"
echo "parallel.log: $parallel_log"
echo
echo "command: $cmd"
echo "args: $@"

eval "$pkg_listing_cmd" | \
    parallel \
    --bar \
    --env OMP_NUM_THREADS \
    --env R_LIBS \
    --joblog "$parallel_log" \
    --jobs "$JOBS_FILE" \
    --files \
    --result "$OUTPUT_DIR/{/}/" \
    --tagstring "$TASK_NAME - {/}" \
    --timeout $TIMEOUT \
    --workdir "$OUTPUT_DIR/{/}/" \
    "$PARALLEL_ARGS" \
    "$cmd" "$PACKAGES_SRC_DIR/{/}" "$@"
