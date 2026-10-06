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
