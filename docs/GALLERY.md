# Gallery notes

## Shell UI
- Full-width card grid that wraps to new rows (vertical scroll only; no horizontal overflow). Modest side padding; no max-width column.
- One global **Original / Enhanced** segmented control; one card per title.
- Card = clickable screenshot + game name only (no per-card Play/edition buttons).
- Mode preference stored in `user://arcade_prefs.cfg`.
- Direct preview shots live in `arcade/previews/<id>_direct.png`.

## In-game scale (`GameRegistry.SCALE_MODE`)
On launch we set the window content-scale policy per title:

| Mode | Window aspect | Stretch | Use when |
|------|---------------|---------|----------|
| `letterbox` | KEEP | INTEGER | Fixed-res / pixel / designed aspect — large centered stage, bars OK |
| `expand` | EXPAND | FRACTIONAL | Control/UI roots that reflow with the window |

Returning to the arcade resets to EXPAND + FRACTIONAL so the gallery reflows.

Picks (Direct/Enhanced share the title policy): see `SCALE_MODE` in `arcade/game_registry.gd`.

## Web loading screen
While `index.wasm` / `index.pck` download, the page shows the rocket avatar
(`arcade/branding/avatar.png`, the same file as the gallery logo and favicon) centered just above the
progress bar, on the gallery background colour. No custom HTML shell is needed:

- `project.godot` → `application/boot_splash/image` = the avatar, `stretch_mode=0` (natural size),
  `bg_color` = the gallery `Background` colour (`#0f0f1a`). The Web export writes the splash as
  `index.png` and the stock shell's `#status` overlay uses it (`$GODOT_SPLASH`, `$GODOT_SPLASH_COLOR`).
  The same image is the native boot splash, so desktop builds match.
- `export_presets.cfg` → `html/head_include` ends with a small `<style>` block that overrides the
  stock shell layout: the splash and progress bar become a centered flex column
  (avatar `min(200px, 40vmin)` wide, bar `min(360px, 70vw)`, accent `#5973f2`).

Download cost: `index.png` goes from the 21,443-byte Godot logo to the 49,398-byte avatar
(+27,955 B, about +0.2% of the gzipped KEY total). `index.pck` +192 B, `index.html` +465 B.
