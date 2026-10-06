#!/usr/bin/env bash
# Capture Direct-edition preview PNGs under Xvfb (needs a real GL context).
set -euo pipefail
GODOT="${GODOT:-$(command -v godot4 || command -v godot || echo /workspace/tools/godot4)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/arcade/previews"
echo "== capture previews ($GODOT) via Xvfb"
xvfb-run -a -s "-screen 0 1280x720x24" \
  "$GODOT" --path "$ROOT" --script res://tools/capture_previews.gd
echo "== done; previews in arcade/previews/"
ls -la "$ROOT/arcade/previews/" || true
