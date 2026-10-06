#!/usr/bin/env bash
# Tear down only what launch.sh started. Never touches evidence/<run>/.
source "$(dirname "$0")/lib.sh"
if [ -f "$PIDFILE" ]; then
	. "$PIDFILE"
	for p in "$GODOT_PID" "$XVFB_PID"; do
		if kill -0 "$p" 2>/dev/null; then kill -- "-$p" 2>/dev/null || kill "$p"; echo "cleanup: stopped pid $p"; fi
	done
	rm -f "$PIDFILE"
fi
rm -f "$EVID/.current"
echo "cleanup: done; evidence kept in $EVID"
ls -1 "$EVID" 2>/dev/null || true
