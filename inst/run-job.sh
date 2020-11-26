#!/bin/bash

OUTPUT=task-output.txt
STATS=task-stats.csv

## ----

_term() {
  echo "Caught SIGTERM signal!" >> "$OUTPUT"
  kill -TERM "$child" 2>/dev/null
}

_int() {
  echo "Caught SIGTERM signal!" >> "$OUTPUT"
  kill -INT "$child" 2>/dev/null
}

if [[ -f "$STATS" && -f "$OUTPUT" ]]; then
    # TODO: check args
    exitval=$(tail -1 "$STATS" | cut -f 1 -d,)
    echo -n "last run: $exitval - "
    case "$RUNR_RERUN" in
        "zero")
            if [[ $exitval -ne 0 ]]; then
                echo "skipping"
                exit 0
            else
                echo "forcing"
            fi
        ;;
        "non-zero")
            if [[ $exitval -eq 0 ]]; then
                echo "skipping"
                exit 0
            else
                echo "forcing"
            fi
        ;;
        "always")
            echo "forcing"
        ;;
        *)
            echo "skipping"
            exit 0
        ;;
    esac
fi

function backup_file {
    file="$1"

    if [ -f $file ]; then
        cnt=$(ls -1 "$file"* | wc -l)
        cnt=$(( $cnt + 1 ))
        cp "$file" "$file.$cnt"
    fi
}

backup_file "$OUTPUT"
rm -f "$OUTPUT"
backup_file "$STATS"
rm -f "$STATS"

command="$@"

start_time="$(date +%s)"

trap _term SIGTERM
trap _int SIGINT

$command > "$OUTPUT" 2>&1 &

child=$!
wait "$child"
exitval=$?

end_time="$(date +%s)"

echo "exitval,hostname,start_time,end_time,command" > "$STATS"
echo "$exitval,$(hostname),$start_time,$end_time,\"$command\"" >> "$STATS"
