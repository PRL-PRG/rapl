#!/usr/bin/env bash

set -e
set -o xtrace

JOBS_FILE="jobsfile.txt"
NUM_JOBS=${NUM_JOBS:-"90%"}
RUN_DIR=${RUN_DIR:-"run"}
TIMEOUT=${TIMEOUT:-"30m"}

if [ $# -lt 1 ]; then
    echo "Usage: $0 <script-to-run> [<args...>]"
    echo ""
    echo "Notes: "
    echo "  - <script-to-run> must be executable and take <args>+1 number of parameters"
    echo "    the first argument will be the path to the source code of a package"
    echo ""
    echo "  - Extra parameters to GNU parallel can be added by PARALLEL_OPTS env variable."
    echo "    For example, using PARALLEL_OPTS='--resume-failed' to retry failed jobs."
    echo ""
    exit 1
fi

# <&0
# cat revdeps.csv | ./run.sh --csv :: ./task/a x1 x2 x3
# echo "a,b" | ./run.sh --csv :: ./task/a x1 x2 x3

: "${R_LIBS:?Not set}"
: "${R_BIN_DIR:?Not set}"
: "${RUN_DIR:?Not set}"

# process arguments
# the parallel args are separated by ::

parallel_opts="$EXTRA_PARALLEL_OPTS"
opts=""
cmd=""

while [[ $# -gt 0 ]]; do
    if [ "$1" == "::" ]; then
        parallel_opts="$parallel_opts $cmd $opts"
        opts=""
        cmd=""
    elif [ -z "$cmd" ]; then
        cmd="$1"
    else
        opts="$opts$1 "
    fi
    shift 1
done

# trimp white spaces
parallel_opts="${parallel_opts##*( )}"
parallel_opts="${parallel_opts%%*( )}"

cmd="$(realpath $cmd)"

if [ ! -x "$cmd" ]; then
    echo "$cmd: is not executable" >2
    exit 1
fi

TASK_NAME=${TASK_NAME:-$(basename "${cmd%.*}")}

[ -d "$RUN_DIR" ] || mkdir -p "$RUN_DIR"

OUTPUT_DIR=$RUN_DIR/$TASK_NAME

[ -d "$OUTPUT_DIR" ] || mkdir -p "$OUTPUT_DIR"

parallel_log="$OUTPUT_DIR/parallel.log"
parallel_results="$OUTPUT_DIR/parallel-results.csv"
parallel_results="$OUTPUT_DIR/{/}/"

echo "* R_LIBS: $R_LIBS"
echo "* R_BIN_DIR: $R_BIN_DIR"
echo "* TASK_NAME: $TASK_NAME"
echo "* OUTPUT_DIR: $OUTPUT_DIR"
echo "* parallel opts: $parallel_opts"
echo "* parallel.log: $parallel_log"
echo "* parallel-results.csv: $parallel_results"
echo "* cmd: $cmd $opts"

function backup_file {
    file="$1"

    if [ -f $file ]; then
        cnt=$(ls -1 "$file"* | wc -l)
        cnt=$(( $cnt + 1 ))
        cp "$file" "$file.$cnt"
    fi
}

# backup parallel log
#backup_file "$parallel_log"
#backup_file "$parallel_results"

echo "$NUM_JOBS" > "$JOBS_FILE"

## assemble the environment
# try to work out around too much parallelism
export OMP_NUM_THREADS=1

parallel \
    --bar \
    --files \
    --env OMP_NUM_THREADS \
    --env R_LIBS \
    --joblog "$parallel_log" \
    --jobs "$JOBS_FILE" \
    --result "$parallel_results" \
    --tagstring "$TASK_NAME - {}" \
    --timeout $TIMEOUT \
    --workdir "$OUTPUT_DIR/{1}/" \
    $parallel_opts \
    "$cmd" $opts

R --slave \
  -e "rapr::normalize_parallel_logs('$OUTPUT_DIR', 'parallel.log');" \
  -e "rapr::normalize_parallel_results('$OUTPUT_DIR', 'parallel-results.csv')"
