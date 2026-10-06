#!/usr/bin/env bash
# Shared settings for verify-arcade helpers. Sourced, not run.
set -euo pipefail
HELPERS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(dirname "$HELPERS")"
ROOT="$(cd "$SKILL/../../.." && pwd)"
GODOT="${GODOT:-/workspace/tools/godot4}"
GODOT_WANT="4.7.2"
EVID="${VERIFY_ARCADE_EVIDENCE:-$SKILL/evidence}"
PIDFILE="$EVID/.godot-gui.pid"
PAGES_URL="https://tangentstorm.github.io/arcade/"
RES_HELPERS="res://.cursor/skills/verify-arcade/helpers"

# Current run dir: $VERIFY_RUN, else the one launch.sh recorded, else a new one.
run_dir() {
	local d="${VERIFY_RUN:-}"
	if [ -z "$d" ] && [ -f "$EVID/.current" ]; then d="$(cat "$EVID/.current")"; fi
	if [ -z "$d" ]; then d="$EVID/$(date +%Y%m%d-%H%M%S)"; fi
	mkdir -p "$d"
	echo "$d"
}

# Fail if a Godot log has engine/script errors or SMOKE FAIL lines.
log_clean() {
	! grep -nE "SCRIPT ERROR|Parse Error|ERROR:|SMOKE FAIL|VERIFY FAIL" "$1"
}
