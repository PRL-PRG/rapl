#!/usr/bin/env bash

set -e

CMD="$0 $@"
TIMEOUT=${RUNR_TIMEOUT:-30m}
JOBS=${RUNR_JOBS:-1}
OUTPUT_DIR=${RUNR_OUTPUT_DIR:-run}
INPUT_FILE=${RUNR_INPUT_FILE:-'-'}
EXEC_WRAPPER=${RUNR_EXEC_WRAPPER:-"$(dirname $(realpath "$0"))/run-job.sh"}
DEF_WORK_DIR=${RUNR_WORK_DIR:-'{=1 $_=join("/",@arg) =}'}

usage() {
cat << EOF
Usage: $0 [options] [-- <extra args>]

Options:
  -h | -help            show this help
  -v | --verbose        verbose output
  -f | --file FILE      the input file
                        - in the case of a CSV file, each row represents a job
                          and each column an command line argument
                        - in the case of non-csv file, each row represents
                          one argument
                        (default $INPUT_FILE)
  -o | --output DIR     DIR to store jobs output
                        (default $OUTPUT_DIR)
  -t | --timeout TIME   timeout in seconds or with a suffix m,h,d
                        (default $TIMEOUT)
  -j | --jobs NUM       number of jobs
                        (default $JOBS)
  -e | --exec FILE      a file to execute
                        it will be executed for each job with arguments from
                        the input file followed by all <extra args>
  -w | --workdir DIR    a subdirectory of output which will be used as working directory for a job
                        (default output/$DEF_WORK_DIR) all input parameters separated by '/'
  --no-exec-wrapper     disable exec wrapper
  --override            override output


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
EXEC_EXTRA_ARGS=""
# PARALLEL_EXTRA_ARGS="--halt now,fail=25%"
PARALLEL_EXTRA_ARGS=""
PARSING_EXEC_EXTRA_ARGS=0
VERBOSE=0

parse_arg() {
    if [[ -n "$2" ]] && [ ${2:0:1} != "-" -o ${#2} -eq 1 ]; then
        eval "$1='$2'"
    else
        echo "Error: $1 is missing argument" >&2
        exit 1
    fi
}

while (( "$#" )); do
  if [[ $PARSING_EXEC_EXTRA_ARGS -eq 0 ]]; then
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -v[v]*|--verbose)
            v=$(echo "$1" | awk -Fv '{print NF-1}')
            ((VERBOSE=VERBOSE+v))
            shift
            ;;
        -e|--exec)
            parse_arg EXEC $2
            shift 2
            ;;
        -f|--file)
            parse_arg INPUT_FILE $2
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
        -w|--workdir)
            parse_arg WORK_DIR $2
            shift 2
            ;;
        --no-exec-wrapper)
            EXEC_WRAPPER=""
            shift
            ;;
        --override)
            OUTPUT_DIR_OVERRIDE=1
            shift
            ;;
        --)
            PARSING_EXEC_EXTRA_ARGS=1
            shift
            ;;
        *)
            PARALLEL_EXTRA_ARGS="$PARALLEL_EXTRA_ARGS $1"
            shift
            ;;
    esac
  else
    EXEC_EXTRA_ARGS="$EXEC_EXTRA_ARGS $1"
    shift
  fi
done

if [[ $VERBOSE -ge 2 ]]; then
    set -o xtrace
fi


if [[ -n "$EXEC_WRAPPER" ]]; then
  if [[ ! -x "$EXEC_WRAPPER" ]]; then
    echo "$EXEC_WRAPPER: exec wrapper is missing" >&2
    exit 1
  fi
fi

if [[ "$EXEC" == *"/"* ]]; then
  # it is not in PATH, use fully qualified path
  EXEC=$(realpath "$EXEC")
fi

if [[ "$INPUT_FILE" != "-" ]]; then
  if [[ ! -f "$INPUT_FILE" ]]; then
    echo "$INPUT_FILE: no such file"
    exit 1
  else
    INPUT_FILE=$(realpath "$INPUT_FILE")
    PARALLEL_EXTRA_ARGS="$PARALLEL_EXTRA_ARGS -a $INPUT_FILE"

    if [[ "$INPUT_FILE" == *csv ]]; then
      PARALLEL_EXTRA_ARGS="$PARALLEL_EXTRA_ARGS --csv"
    fi
  fi
fi

RESULT_FILE="$OUTPUT_DIR/parallel.csv"

if [ -f "$RESULT_FILE" -a -z "$OUTPUT_DIR_OVERRIDE" ]; then
  echo "$RESULT_FILE already exists!"
  exit 1
fi

[[ -d "$OUTPUT_DIR" ]] || mkdir -p "$OUTPUT_DIR"

OUTPUT_DIR=$(realpath "$OUTPUT_DIR")
PARALLEL_LOG="$OUTPUT_DIR/parallel.log"
JOBS_FILE="$OUTPUT_DIR/jobs.txt"
MAP_CMD_FILE="$OUTPUT_DIR/map-cmd.txt"
TASK_NAME=$(basename "$EXEC")

if [[ -z "$WORK_DIR" ]]; then
  WORK_DIR=$OUTPUT_DIR/$DEF_WORK_DIR
fi

echo "$JOBS" > "$JOBS_FILE"

DEBUG_MSG=$(cat <<-EOM
CMD:      $CMD
INPUT:    $INPUT_FILE
OUTPUT:   $OUTPUT_DIR
TIMEOUT:  $TIMEOUT
JOBS:     $JOBS
EXEC:     $EXEC
WRAPPER:  $EXEC_WRAPPER
WORK_DIR: $WORK_DIR

additional GNU parallel args: $PARALLEL_EXTRA_ARGS"
additional exec args: $EXEC_EXTRA_ARGS"
log file: $PARALLEL_LOG"
result file: $RESULT_FILE"
job file: $JOBS_FILE"
EOM
)

echo "$DEBUG_MSG" > $MAP_CMD_FILE

[[ $VERBOSE -ge 1 ]] && echo "$DEBUG_MSG"

parallel \
  --bar \
  --env RUNR_RERUN \
  --joblog "$PARALLEL_LOG" \
  --results "$RESULT_FILE" \
  --jobs "$JOBS_FILE" \
  --tagstring "$TASK_NAME - {}" \
  --timeout "$TIMEOUT" \
  --workdir "$WORK_DIR" \
  $PARALLEL_EXTRA_ARGS \
  "$EXEC_WRAPPER" \
  "$EXEC" \
  $EXEC_EXTRA_ARGS
