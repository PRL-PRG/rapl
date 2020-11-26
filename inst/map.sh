#!/usr/bin/env bash

set -e

TIMEOUT=${RUNR_TIMEOUT:-30m}
JOBS=${RUNR_JOBS:-1}
OUTPUT_DIR=${RUNR_OUTPUT_DIR:-run}

usage() {
cat << EOF
Usage: $0 [options] [-- <extra args>]

Options:
  -h | -help            show this help
  -v | --verbose        verbose output
  -f | --file FILE      the input file (or '-' to indicate stdin)
                        - in the case of a CSV file, each row represents a job
                          and each column an command line argument
                        - in the case of non-csv file, each row represents
                          one argument
  -o | --output DIR     DIR to store jobs output
                        (default $OUTPUT_DIR)
  -t | -timeout TIME    timeout in seconds or with a suffix m,h,d
                        (default $TIMEOUT)
  -j | -jobs NUM        number of jobs
                        (default $JOBS)
  -e | -exec FILE       a file to execute
                        it will be executed for each job with arguments from
                        the input file followed by all <extra args>

  any other optionss will be passed to GNU parallel arguments

Note:
  - it is possible to use GNU parallel variable interpolation
    inside the additional arguments
  - each job is run from ???
  - use absolute paths
  - use '--skip-first-line' if there is a header in the CSV file
EOF
}

RUNR_INST_DIR=$(dirname $(realpath "$0"))
EXEC_WRAPPER=${RUNR_EXEC_WRAPPER:-"$RUNR_INST_DIR/run-job.sh"}
EXEC_EXTRA_ARGS=""
PARALLEL_EXTRA_ARGS="--halt now,fail=25%"
PARSING_EXEC_EXTRA_ARGS=0
VERBOSE=0

[[ -x "$EXEC_WRAPPER" ]] || {
    echo "$EXEC_WRAPPER: exec wrapper is missing" >&2
    exit 1
}

parse_arg() {
    if [[ -n "$2" ]] && [[ ${2:0:1} != "-" ]]; then
        eval "$1='$2'"
    else
        echo "Error: $1 is missing argument" >&2
        exit 1
    fi
}

while (( "$#" )); do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -v[v]*|--verbose)
            v=$(echo "$1" | awk -F, '{print NF-1}')
            ((VERBOSE=VERBOSE+v))
            shift
            ;;
        -e|--exec)
            parse_arg EXEC $2
            if [[ "$EXEC" == *"/"* ]]; then
              # it is not in PATH, use fully qualified path
              EXEC=$(realpath "$EXEC")
            fi
            shift 2
            ;;
        -f|--file)
            parse_arg INPUT_FILE $2
            INPUT_FILE=$(realpath "$INPUT_FILE")
            if [[ ! -f "$INPUT_FILE" ]]; then
              echo "$INPUT_FILE: no such file"
              exit 1
            fi
            if [[ "$INPUT_FILE" == *csv ]]; then
                PARALLEL_EXTRA_ARGS="$PARALLEL_EXTRA_ARGS --csv"
            fi
            if [[ "$INPUT_FILE" != "-" ]]; then
                PARALLEL_EXTRA_ARGS="$PARALLEL_EXTRA_ARGS -a $INPUT_FILE"
            fi
            shift 2
            ;;
        -j|--jobs)
            parse_arg JOBS $2
            shift 2
            ;;
        -o|--output)
            parse_arg OUTPUT_DIR $2
            shift 2
            ;;
        -t|--timeout)
            parse_arg TIMEOUT $2
            shift 2
            ;;
        --)
            PARSING_EXEC_EXTRA_ARGS=1
            shift
            ;;
        *)
            if [[ $PARSING_EXEC_EXTRA_ARGS -eq 1 ]]; then
                EXEC_EXTRA_ARGS="$EXEC_EXTRA_ARGS $1"
            else
                PARALLEL_EXTRA_ARGS="$PARALLEL_EXTRA_ARGS $1"
            fi
            shift
            ;;
    esac
done

if [[ $VERBOSE -ge 2 ]]; then
    set -o xtrace
fi

[[ -d "$OUTPUT_DIR" ]] || mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")

PARALLEL_LOG="$OUTPUT_DIR/parallel.log"
RESULT_FILE="$OUTPUT_DIR/parallel.csv"
JOBS_FILE="$OUTPUT_DIR/jobs.txt"
TASK_NAME=$(basename "$EXEC")

# backup parallel log
if [ -f $PARALLEL_LOG ]; then
    cnt=$(ls -1 "$PARALLEL_LOG"* | wc -l)
    cnt=$(( $cnt + 1 ))
    cp "$PARALLEL_LOG" "$PARALLEL_LOG.$cnt"
fi

echo "$JOBS" > "$JOBS_FILE"

if [[ $VERBOSE -ge 1 ]]; then
cat <<EOF
INPUT:   $INPUT_FILE
OUTPUT:  $OUTPUT_DIR
TIMEOUT: $TIMEOUT
JOBS:    $JOBS
EXEC:    $EXEC

additional GNU parallel args: $PARALLEL_EXTRA_ARGS"
additional exec args: $EXEC_EXTRA_ARGS"
log file: $PARALLEL_LOG"
result file: $RESULT_FILE"
job file: $JOBS_FILE"
EOF
fi

parallel \
  --bar \
  --env RUNR_RERUN \
  --joblog "$PARALLEL_LOG" \
  --result "$RESULT_FILE" \
  --jobs "$JOBS_FILE" \
  --tagstring "$TASK_NAME - {}" \
  --timeout "$TIMEOUT" \
  --workdir $OUTPUT_DIR/'{=1 $_=join("/",@arg) =}' \
  $PARALLEL_EXTRA_ARGS \
  "$EXEC_WRAPPER" \
  "$EXEC" \
  $EXEC_EXTRA_ARGS
