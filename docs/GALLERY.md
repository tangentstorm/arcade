# Gallery notes

## Shell UI
- Full-width card grid that wraps to new rows (vertical scroll only; no horizontal overflow). Modest side padding; no max-width column.
- One global **Original / Enhanced** segmented control; one card per title.
- Card = clickable screenshot + game name only (no per-card Play/edition buttons).
- Mode preference stored in `user://arcade_prefs.cfg`.
- Direct preview shots live in `arcade/previews/<id>_direct.png`. An edition-specific shot
  (`<id>_enhanced.png`) is used for that edition when present; otherwise the Direct shot is shown.

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
| `brickslayer` (Enhanced) | 1280×720 stage; 400×300 field @2× + side HUD | `letterbox` | Procedural restyle on the Direct rules (subclass). No `_enhanced` preview yet (the gallery card uses the Direct shot) |
| `mineswpr` (Enhanced) | 1280×720 stage; 16×16 board of 38 px tiles + side panels | `letterbox` | Presentation over the Direct logic + shell (preload). No `_enhanced` preview yet (the gallery card uses the Direct shot) |
| `shep` (Enhanced) | 1280×720 stage; 800×575 Direct field centered + side HUD | `letterbox` | Presentation over Direct physics (preload). Color rings, aim assist, juice. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `cupid` (Enhanced) | 1280×720 stage; 656×350 Direct stage @1.75× (1148×612) + title bar / stats strip | `letterbox` | Presentation over Direct logic (preload). Storm→sunset duotone city, bubbles/HUD juice. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `gm_defense` (Enhanced) | 1280×720 stage; 1024×768 r_main @0.75× (768×576) clipped field + side HUD + radar strip | `letterbox` | Presentation over Direct logic (preload). Deep-space room, ship/squid glow, off-room locator. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `ok_defender` (Enhanced) | 1280×720 stage; 320×200 Direct world @3× (960×600) + side HUD | `letterbox` | Presentation over Direct logic (preload). Ship/terrain/HUD juice. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `ld48` (Enhanced) | 1280×720 stage; full-bleed Direct rooms in a SubViewport + overlay chrome | `expand` (title) | Presentation over Direct rooms/scripts (instance). Restyled chat/help, juice. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `silly_game` (Enhanced) | camera-followed open map (Direct zoom ½) + overlay HUD/minimap | `expand` (title) | Presentation over the Direct scene (instance). Ocean shader, trails, hit juice. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `giraffe` (Enhanced) | 1280×720 stage; 128×128 Pico room @5× (640×640) + side HUD | `letterbox` | Presentation over Direct logic (preload). Dusk backdrop, squash/stretch, dust, ledge tracker. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `killem_all` (Enhanced) | 1280×720 stage; 1024×768 room0 @0.8125 (832×624) + side HUD panels | `letterbox` | Presentation over Direct logic (preload `ka_world.gd`). Neon arena, tracers, thrust flame, radar. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `terratri` (Enhanced) | 1280×720 designed stage (560 px board + two 312 px player cards) self-fitted; backdrop fills the window | `expand` (title) | Presentation over Direct rules (preload). Tabletop board, hop/claim/fort juice, turn banners. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `canyon_run` (Enhanced) | 1280×720 stage; 240×320 Direct stage @2× (480×640) clipped field + side HUD | `letterbox` | Presentation over Direct logic (preload `canyon_logic.gd`). Layered canyon, craft/exhaust juice, clearer HUD. Design parity deferred. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `sketchbots` (Enhanced) | 1280×720 stage; 300×300 Direct sketch @2× (600×600) clipped field + side HUD | `letterbox` | Presentation over Direct logic (preload `sketchbots_logic.gd`). Bot glow/squash/dust, meet + off-canvas juice. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `doth` (Enhanced) | 1280×720 stage; 70×20 @16px (1120×320) + bottom HUD | `letterbox` | Presentation over Direct world + SvA-like tiles (preload). Torchlit chrome, pickup juice. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `chesscoach` (Enhanced) | 1280×720 stage; Direct ~400×400 board in SubViewport → 520×520 field + side HUD | `letterbox` | Presentation over Direct scene (instance). Walnut board, move-list HUD, replay juice. No `_enhanced` preview yet (gallery can use the Direct shot) |
| `doth` | 1120×368 (70×20 @16px + HUD) | `letterbox` | Doth-A Direct MVP (#35); SvA-like procedural tiles |
| `flappy_clone` (Enhanced) | 1280×720 stage, 107 px/unit | `letterbox` | First Enhanced edition. Procedural art, scaled to fit the viewport. No `_enhanced` preview yet (the gallery card uses the Direct shot) |
| `tentraminos` (Enhanced) | 568×646 board + 520 px HUD panel (1124×646) in 1280×720 | `letterbox` | Same rules as Direct. `tentraminos_enhanced.png` preview |
| `tetraminex` | 480×480 grid in 720² frame + side HUD | `letterbox` | Direct = NES chat; Enhanced = readable card + procedural tiles (same rooms) |

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
| `chesscoach` | Chess Coach | playable (Direct + Enhanced) | letterbox (Direct 400×400; Enhanced 1280×720) | gd-chesscoach FEN board + trays; Enhanced = walnut chrome over Direct scene; no Stockfish |
| `canyon_run` | Canyon Run | playable (Direct + Enhanced) | letterbox (Direct 240×320 @2×; Enhanced 1280×720) | Original River Raid–style flyer; Enhanced = layered canyon chrome + HUD/juice over Direct logic; Design parity deferred |
| `sketchbots` | SketchBots | playable (Direct + Enhanced) | letterbox (Direct 300×300; Enhanced 1280×720) | GameSketchLib w01 two-player movers; Enhanced = glow/juice + off-canvas locators over Direct logic |
| `terratri` | Terratri | playable (+ Enhanced) | expand | hotseat 2P, pure GDScript rules (see below); Enhanced = tabletop makeover over the same rules |

## Local hotseat titles
Some board games ship as **hotseat 2P** Direct editions: both players share one
window and take turns, with no network. The first is `terratri`, which was a
two-browser WebSocket game in the original. Its card launches straight into a
game with Red to move. It uses the `expand` scale mode, and the board picks a
whole-number cell size so it stays crisp at any window size. Rules are pure
GDScript, checked against golden playouts recorded from the original TS
(`tools/test_terratri.gd`).
