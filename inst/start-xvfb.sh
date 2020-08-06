#!/bin/bash

if [ -z "$NO_DISPLAY" -a -z "$DISPLAY" ]; then
    local_display=:6

    pid=$(pgrep Xvfb)
    if [ $? -ne 0 ]; then
        echo "Starting Xvfb..."
        nohup Xvfb $local_display -screen 0 1280x1024x24 >/dev/null 2>&1 &
        pid=$!
        # give Xvfb a bit of a time before it is initialized
        sleep 1
    fi

    if ! env DISPLAY=$local_display xdpyinfo >/dev/null 2>&1 ; then
        echo "There is something wrong with the Xvfb server." >&2
        echo "The environment is not correctly set!" >&2
    else
        export DISPLAY=$local_display
    fi
fi
