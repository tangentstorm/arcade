#!/usr/bin/env bash
set -euo pipefail
GODOT="${GODOT:-$(command -v godot4 || command -v godot || echo /workspace/tools/godot4)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xvfb-run -a -s "-screen 0 1280x800x24" \
  "$GODOT" --path "$ROOT" --window-size 1280,800 --script res://tools/shot_doth_term.gd
