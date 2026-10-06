#!/usr/bin/env bash
# Capture gallery preview PNGs under Xvfb (needs a real GL context).
# Env: CAPTURE_EDITION=direct (default) | enhanced | both
#      CAPTURE_ONLY=<id> limits to one title; CAPTURE_FORCE=1 re-shoots existing.
# Output: arcade/previews/<id>_<edition>.png at 640x360.
set -euo pipefail
GODOT="${GODOT:-$(command -v godot4 || command -v godot || echo /workspace/tools/godot4)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/arcade/previews"
export CAPTURE_EDITION="${CAPTURE_EDITION:-direct}"
echo "== capture previews ($GODOT, edition=$CAPTURE_EDITION) via Xvfb"
xvfb-run -a -s "-screen 0 1280x720x24" \
  "$GODOT" --path "$ROOT" --script res://tools/capture_previews.gd
echo "== done; previews in arcade/previews/"
ls -la "$ROOT/arcade/previews/" || true
