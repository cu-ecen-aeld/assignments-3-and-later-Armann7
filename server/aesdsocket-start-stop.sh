#!/bin/sh
# Simple init script for mydaemon

DAEMON="/usr/bin/aesdsocket"
PIDFILE="/var/run/aesdsocket.pid"

case "$1" in
    start)
        echo "Starting aesdsocket..."
        nohup $DAEMON > /dev/null 2>&1 &
        echo $! > $PIDFILE
        echo "aesdsocket started."
        ;;
    stop)
        echo "Stopping aesdsocket..."
        kill "$(cat $PIDFILE)"
        rm -f $PIDFILE
        echo "aesdsocket stopped."
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac

exit 0
