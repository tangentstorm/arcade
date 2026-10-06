#!/usr/bin/env bash
# ASCII-only UI string lint — see tools/lint_ascii_ui.py and tools/ascii_ui_allowlist.txt
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$ROOT/tools/lint_ascii_ui.py" --root "$ROOT" "$@"
