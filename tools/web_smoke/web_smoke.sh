#!/usr/bin/env bash
# Browser smoke for the real Web export (the slim template): export a temp copy of the
# project with web_smoke.gd injected as an autoload, serve it gzipped like GitHub Pages,
# open it in headless Chrome, visit every playable scene, and fail on any console error.
#
#   GODOT=/workspace/tools/godot4 ./tools/web_smoke/web_smoke.sh [boot|smoke]   (default: smoke)
#
# Needs node + npm and Chrome (CHROME=/path/to/chrome, default /usr/bin/google-chrome).
set -euo pipefail
MODE="${1:-smoke}"
GODOT="${GODOT:-$(command -v godot4 || command -v godot || echo /workspace/tools/godot4)}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/tools/web_smoke"
NODE_DIR="$ROOT/.cache/web_smoke"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ ! -d "$NODE_DIR/node_modules/playwright-core" ]; then
  mkdir -p "$NODE_DIR" && touch "$ROOT/.cache/.gdignore"
  npm install --silent --prefix "$NODE_DIR" playwright-core >/dev/null
fi

echo "== copy project -> $TMP/proj"
mkdir -p "$TMP/proj"
tar -C "$ROOT" --exclude=./.git --exclude=./build --exclude=./.cache --exclude=./.godot -cf - . | tar -C "$TMP/proj" -xf -
mkdir -p "$TMP/proj/websmoke"
cp "$HERE/web_smoke.gd" "$TMP/proj/websmoke/web_smoke.gd"
if [ "$MODE" = smoke ]; then
  # Add the autoload as the first entry of [autoload].
  sed -i 's#^\[autoload\]$#[autoload]\nWebSmoke="*res://websmoke/web_smoke.gd"#' "$TMP/proj/project.godot"
fi

echo "== import + export"
"$GODOT" --headless --path "$TMP/proj" --import >/dev/null 2>&1 || true
mkdir -p "$TMP/web"
"$GODOT" --headless --path "$TMP/proj" --export-release "Web" "$TMP/web/index.html" >"$TMP/export.log" 2>&1 \
  || { cat "$TMP/export.log"; echo "web_smoke: export FAILED"; exit 1; }
ls -l "$TMP/web"

echo "== headless Chrome ($MODE)"
cp "$HERE/run.mjs" "$NODE_DIR/run.mjs"
if node "$NODE_DIR/run.mjs" "$TMP/web" "$MODE" "${SHOT:-}"; then echo "web_smoke: OK"; else echo "web_smoke: FAILED"; exit 1; fi
