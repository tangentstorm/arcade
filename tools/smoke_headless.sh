#!/usr/bin/env bash
# Headless smoke test: import the project, then boot the arcade for a few frames
# and visit every playable scene. Fails on script/parse errors.
set -euo pipefail
GODOT="${GODOT:-$(command -v godot4 || command -v godot || echo /workspace/tools/godot4)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

echo "== import ($GODOT)"
"$GODOT" --headless --path "$ROOT" --import 2>&1 | tee "$LOG"

echo "== boot arcade"
"$GODOT" --headless --path "$ROOT" --quit-after 30 2>&1 | tee -a "$LOG"

echo "== visit playable scenes"
"$GODOT" --headless --path "$ROOT" --script res://tools/smoke_scenes.gd 2>&1 | tee -a "$LOG"

if grep -E "SCRIPT ERROR|Parse Error|ERROR:|SMOKE FAIL" "$LOG"; then
	echo "smoke: FAILED"; exit 1
fi
echo "smoke: OK"
