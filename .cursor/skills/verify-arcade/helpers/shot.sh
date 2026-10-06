#!/usr/bin/env bash
# Screenshot the GUI started by `launch.sh --gui`.  Usage: shot.sh <name>
# -> $RUN/<name>.png.  Drive that window with: DISPLAY=... xdotool ...
source "$(dirname "$0")/lib.sh"
[ -f "$PIDFILE" ] || { echo "shot: no GUI run (launch.sh --gui)"; exit 1; }
. "$PIDFILE"
RUN="$(run_dir)"
out="$RUN/${1:?name}.png"
ffmpeg -loglevel error -y -f x11grab -video_size 1280x720 -i "$DISPLAY" -frames:v 1 "$out"
echo "shot: $out"
