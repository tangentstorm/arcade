#!/usr/bin/env bash
# Whole-repo regression: tools/smoke_headless.sh (import, boot, every scene,
# every tools/test_*.gd).  Evidence -> $RUN/smoke.log ; exit = script's exit.
source "$(dirname "$0")/lib.sh"
RUN="$(run_dir)"
set +e
GODOT="$GODOT" "$ROOT/tools/smoke_headless.sh" >"$RUN/smoke.log" 2>&1
rc=$?
set -e
grep -E "^== |^ok:|SMOKE FAIL|^smoke:" "$RUN/smoke.log" | tail -40
echo "smoke: exit $rc (evidence $RUN/smoke.log)"
exit $rc
