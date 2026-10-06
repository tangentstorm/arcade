#!/usr/bin/env bash
# Drive edition-toggle + launch-game-and-return with real injected input.
# Usage: flow.sh [--headless] [card title, default Tetraminex]
#   default: Xvfb window with PNG per step; --headless: no PNGs, faster.
# Evidence -> $RUN/flow-<title>.log [+ 01-gallery.png ... 05-back.png in $RUN/flow-<title>/]
source "$(dirname "$0")/lib.sh"
RUN="$(run_dir)"
mode=xvfb
if [ "${1:-}" = "--headless" ]; then mode=headless; shift; fi
GAME="${1:-Tetraminex}"
slug="$(echo "$GAME" | tr -c 'A-Za-z0-9\n' '_')"
OUT="$RUN/flow-$slug"; LOG="$RUN/flow-$slug.log"
mkdir -p "$OUT"
cd "$ROOT"
echo "== flow ($mode) card '$GAME' -> $LOG"
set +e
if [ "$mode" = headless ]; then
	VERIFY_OUT="$OUT" VERIFY_GAME="$GAME" "$GODOT" --headless --path "$ROOT" \
		--script "$RES_HELPERS/drive_flow.gd" >"$LOG" 2>&1
else
	VERIFY_OUT="$OUT" VERIFY_GAME="$GAME" xvfb-run -a -s "-screen 0 1280x720x24" \
		"$GODOT" --audio-driver Dummy --path "$ROOT" --script "$RES_HELPERS/drive_flow.gd" >"$LOG" 2>&1
fi
rc=$?
set -e
grep -E "^(step ok|info|shot|VERIFY)" "$LOG" || true
status=0
[ "$rc" -eq 0 ] && grep -q "VERIFY DONE: 0" "$LOG" && log_clean "$LOG" || status=1
echo "flow: $([ $status -eq 0 ] && echo PASS || echo FAIL) (exit $rc, evidence $LOG)"
exit $status
