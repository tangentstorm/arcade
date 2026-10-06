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

Recent Direct ports: **Giraffe** (`giraffe`) is a 128×128 Pico-8 stage (`letterbox`).

Fixed-stage notes:

| id | stage | mode | notes |
|----|-------|------|-------|
| `canyon_run` | 240×320 portrait @2× (480×640) centred in 1280×720 | `letterbox` | Procedural Direct MVP (#36); Enhanced will follow the Claude Design mock |
| `doth` | 1120×368 (70×20 @16px + HUD) | `letterbox` | Doth-A Direct MVP (#35); SvA-like procedural tiles |
| `flappy_clone` (Enhanced) | 1280×720 stage, 107 px/unit | `letterbox` | First Enhanced edition. Procedural art, scaled to fit the viewport. No `_enhanced` preview yet (the gallery card uses the Direct shot) |

## Back button (`ArcadeHistory` autoload)
Every edition gets Back support from the shell. No per-game code is needed: it hooks
`GameRegistry.launched` / `GameRegistry.returned_to_arcade`.

| Platform | Back from a game | Notes |
|----------|------------------|-------|
| Web (browser Back) | returns to the gallery in one step, even from the pause panel | `launch()` pushes `#play/<id>/<edition>`; `return_to_arcade()` uses `replaceState` back to the bare URL (never `history.back()`) |
| Web (browser Forward / typed hash) | `#play/<id>/<edition>` relaunches that entry if it is playable | invalid or unplayable hashes are rewritten to the gallery |
| Web cold load with `#play/...` | deep link opens the game; Back then lands on the gallery | the landing entry is rewritten to the gallery and the play entry pushed on top |
| Android (system Back) | returns to the gallery; Back on the gallery quits | arrives as `NOTIFICATION_WM_GO_BACK_REQUEST`, **not** `ui_cancel`; needs `application/config/quit_on_go_back=false` (set in `project.godot`) |
| Desktop / editor | unchanged | Esc: pause panel, Esc again (or "Back to Arcade"): gallery |

Leaving a game with Esc / an in-game Back button leaves a gallery entry where the play entry
was, so the next browser Back from the gallery is a no-op (stays on the gallery) and the one
after that leaves the site.

Checks: `tools/test_arcade_history.gd` (headless, non-web path) and
`./tools/web_smoke/web_smoke.sh back` (real export in headless Chrome: launch, Back, Forward,
Back while paused, Esc return, deep link, invalid deep link).

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

## Titles (selected)

| id | title | Direct | scale | notes |
|----|-------|--------|-------|-------|
| `chesscoach` | Chess Coach | playable | letterbox (400×400) | gd-chesscoach FEN board + trays; no Stockfish |
| `terratri` | Terratri | playable | expand | hotseat 2P, pure GDScript rules (see below) |

## Local hotseat titles
Some board games ship as **hotseat 2P** Direct editions: both players share one
window and take turns, with no network. The first is `terratri`, which was a
two-browser WebSocket game in the original. Its card launches straight into a
game with Red to move. It uses the `expand` scale mode, and the board picks a
whole-number cell size so it stays crisp at any window size. Rules are pure
GDScript, checked against golden playouts recorded from the original TS
(`tools/test_terratri.gd`).
