# tools/

Harnesses and local gates for `tangentstorm/arcade`.

## ASCII UI lint (`lint_ascii_ui`)

Default Godot fonts lack many glyphs (arrows, card suits, math ops), so non-ASCII
UI strings can ship as tofu (`□`). This lint fails on non-ASCII **string literals**
in `arcade/` and `games/` (`.gd` / `.tscn`), skipping `games/*/source/` and
comment-only GDScript lines.

```bash
./tools/lint_ascii_ui.sh
# or
python3 tools/lint_ascii_ui.py
```

**Exceptions:** add a path or `path:line` to [`ascii_ui_allowlist.txt`](./ascii_ui_allowlist.txt)
with a `# font: …` note naming the FontFile (or primitive draw path) that covers
the glyphs. Prefer ASCII replacements when the default font is in use.

Wired into [`smoke_headless.sh`](./smoke_headless.sh) (runs before Godot import)
and optionally from verify-arcade `doctor.sh`.

## Smoke

```bash
GODOT=/workspace/tools/godot4 ./tools/smoke_headless.sh
```
