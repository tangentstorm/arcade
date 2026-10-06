#!/usr/bin/env bash
# Start a verification run.
#   launch.sh          new evidence run + headless import (enough for all
#                      headless/Xvfb-per-script drives: layout, flow, smoke)
#   launch.sh --gui    also start ONE interactive arcade window on a private
#                      Xvfb display (pids in evidence/.godot-gui.pid)
# Prints the run dir; later helpers pick it up from evidence/.current.
source "$(dirname "$0")/lib.sh"
mkdir -p "$EVID"
RUN="${VERIFY_RUN:-$EVID/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$RUN"
echo "$RUN" >"$EVID/.current"
( cd "$ROOT" && git rev-parse HEAD && git status --short ) >"$RUN/build.txt" 2>&1 || true
echo "== import -> $RUN/import.log"
"$GODOT" --headless --path "$ROOT" --import >"$RUN/import.log" 2>&1
log_clean "$RUN/import.log" || { echo "launch: import errors"; exit 1; }
if [ "${1:-}" = "--gui" ]; then
	if [ -f "$PIDFILE" ]; then
		echo "launch: a GUI run is already recorded in $PIDFILE — run cleanup.sh first"; exit 1
	fi
	n=91; while [ -e "/tmp/.X$n-lock" ]; do n=$((n+1)); done
	setsid Xvfb ":$n" -screen 0 1280x720x24 -nolisten tcp >"$RUN/xvfb.log" 2>&1 &
	xpid=$!
	sleep 1
	DISPLAY=":$n" setsid "$GODOT" --audio-driver Dummy --path "$ROOT" >"$RUN/gui.log" 2>&1 &
	gpid=$!
	printf 'XVFB_PID=%s\nGODOT_PID=%s\nDISPLAY=:%s\n' "$xpid" "$gpid" "$n" >"$PIDFILE"
	for _ in $(seq 1 40); do
		if DISPLAY=":$n" xdotool search --name "tangentstorm arcade" >/dev/null 2>&1; then
			sleep 2  # window maps before the gallery takes input; clicks earlier are dropped
			echo "launch: GUI ready on DISPLAY=:$n (godot pid $gpid)"; break
		fi
		kill -0 "$gpid" 2>/dev/null || { echo "launch: godot exited, see $RUN/gui.log"; exit 1; }
		sleep 0.5
	done
	DISPLAY=":$n" xdotool search --name "tangentstorm arcade" >/dev/null 2>&1 \
		|| { echo "launch: window never appeared"; exit 1; }
fi
echo "VERIFY_RUN=$RUN"
