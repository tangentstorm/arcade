#!/usr/bin/env bash
# Drive gallery-browse-layout: repo's headless layout test (+ optional Xvfb shots).
# Usage: layout.sh [--shots]   (VERIFY_SIZES="WxH ..." overrides the shot sizes)
# Evidence -> $RUN/layout.log [, gallery-<WxH>.png, shots.log]
source "$(dirname "$0")/lib.sh"
RUN="$(run_dir)"
cd "$ROOT"
echo "== layout test -> $RUN/layout.log"
set +e
"$GODOT" --headless --path "$ROOT" --script res://tools/test_gallery_layout.gd >"$RUN/layout.log" 2>&1
rc=$?
set -e
grep -E "^ok:|SMOKE FAIL" "$RUN/layout.log" || true
oks=$(grep -c "^ok: gallery fits" "$RUN/layout.log" || true)
status=0
[ "$rc" -eq 0 ] || { echo "layout: godot exit $rc"; status=1; }
log_clean "$RUN/layout.log" || { echo "layout: errors in log (did launch.sh import?)"; status=1; }
[ "$oks" -ge 6 ] || { echo "layout: only $oks/6 sizes checked"; status=1; }
if [ "${1:-}" = "--shots" ]; then
	echo "== gallery screenshots (Xvfb, one window per size) -> $RUN/shots.log"
	: >"$RUN/shots.log"
	for s in ${VERIFY_SIZES:-1280x800 1024x570 800x600 600x800 1920x1080 2560x800}; do
		set +e
		VERIFY_OUT="$RUN" xvfb-run -a -s "-screen 0 2560x1600x24" \
			"$GODOT" --audio-driver Dummy --resolution "$s" --path "$ROOT" \
			--script "$RES_HELPERS/gallery_shots.gd" >"$RUN/shots-$s.log" 2>&1
		src=$?
		set -e
		cat "$RUN/shots-$s.log" >>"$RUN/shots.log"
		grep -E "^shot:|VERIFY FAIL" "$RUN/shots-$s.log" || true
		{ [ "$src" -eq 0 ] && log_clean "$RUN/shots-$s.log" >/dev/null; } || { echo "shots: $s failed (exit $src)"; status=1; }
		rm -f "$RUN/shots-$s.log"
	done
fi
echo "layout: $([ $status -eq 0 ] && echo PASS || echo FAIL) (evidence $RUN)"
exit $status
