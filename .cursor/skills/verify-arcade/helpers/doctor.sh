#!/usr/bin/env bash
# Read-only: is this checkout/instance worth driving? Exit 0 = yes.
source "$(dirname "$0")/lib.sh"
bad=0
pass() { echo "ok:   $*"; }
fail() { echo "FAIL: $*"; bad=1; }
warn() { echo "warn: $*"; }
v="$("$GODOT" --version 2>/dev/null | head -1 || true)"
case "$v" in "$GODOT_WANT".*) pass "godot $v ($GODOT)";; *) fail "godot '$v' at $GODOT, want $GODOT_WANT.x";; esac
grep -q 'config/name="tangentstorm arcade"' "$ROOT/project.godot" && pass "project $ROOT" || fail "not the arcade project: $ROOT"
pass "git $(git -C "$ROOT" rev-parse --short HEAD) on $(git -C "$ROOT" branch --show-current), $(git -C "$ROOT" status --short | wc -l) dirty file(s)"
[ -d "$ROOT/.godot/imported" ] && pass ".godot import cache present" || fail "no import cache — run launch.sh (it imports)"
for t in test_gallery_layout.gd smoke_headless.sh smoke_scenes.gd lint_ascii_ui.sh; do
	[ -e "$ROOT/tools/$t" ] && pass "harness tools/$t" || fail "missing tools/$t"
done
if [ -x "$ROOT/tools/lint_ascii_ui.sh" ]; then
	if "$ROOT/tools/lint_ascii_ui.sh" >/dev/null; then pass "ascii UI lint"; else fail "ascii UI lint (./tools/lint_ascii_ui.sh)"; fi
fi
for b in xvfb-run Xvfb xdotool ffmpeg curl; do
	command -v "$b" >/dev/null && pass "$b" || warn "$b missing (Xvfb shots / GUI / pages need it)"
done
if [ -f "$EVID/.current" ]; then pass "current run $(cat "$EVID/.current")"; else warn "no current run — launch.sh not run yet"; fi
if [ -f "$PIDFILE" ]; then
	. "$PIDFILE"
	if kill -0 "$GODOT_PID" 2>/dev/null && DISPLAY="$DISPLAY" xdotool search --name "tangentstorm arcade" >/dev/null 2>&1; then
		pass "GUI arcade up: pid $GODOT_PID on DISPLAY=$DISPLAY (ours)"
	else
		fail "stale $PIDFILE (pid $GODOT_PID gone) — run cleanup.sh"
	fi
fi
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$PAGES_URL" || true)"
[ "$code" = 200 ] && pass "Pages $PAGES_URL -> 200" || warn "Pages $PAGES_URL -> '$code'"
[ $bad -eq 0 ] && echo "doctor: OK" || echo "doctor: FAIL"
exit $bad
