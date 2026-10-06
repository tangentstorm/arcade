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


## Per-game Pages stubs (`gen_game_pages`)

After a Web export, emit thin HTML hosts at `build/web/<slug>/` with per-game
OG/Twitter tags. Each stub loads `../index.js` / `../index.wasm` / `../index.pck`
and bootstraps `#play/<id>/<edition>` (`?e=enhanced` or `#enhanced` → Enhanced;
default Direct). Mineswpr aliases: `/mineswpr/` → `mineswpr_b4`,
`/mineswpr.old/` → `mineswpr`.

```bash
python3 tools/gen_game_pages.py --web-dir build/web
python3 tools/gen_game_pages.py --self-check
python3 tools/gen_game_pages.py --list
```

See [`docs/GALLERY.md`](../docs/GALLERY.md) (Deep-link game pages).

## Smoke

```bash
GODOT=/workspace/tools/godot4 ./tools/smoke_headless.sh
```
