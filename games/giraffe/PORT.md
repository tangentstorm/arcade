# Giraffe — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/pico-games (`giraffe.p8`) |
| Source commit | `2ff3d8d39630dbf7f212d41ded475ed5136e0f1e` (“savleen's sprite”, 2026-03-09) |
| Engine | Pico-8 (cart version 42), 128×128, default 30 Hz |
| License | No LICENSE in the source repo. Code and art are tangentstorm's own work. |

## Direct edition (`direct/`) — playable

- `direct/giraffe_logic.gd` ports `_update` / `init` one frame per `step()` at a fixed 30 Hz.
  - Gravity `dy += 1`; on ground (`mget(mx, my+1) == 16`) and falling → snap `hy = my*8`, jump `dy = -6` while ❎ held.
  - Horizontal: `dx ± 0.4` on ⬅️/➡️, then `dx *= 0.8`, deadzone `< 0.1`.
  - Walk anim: `tm` every frame; every 5 frames toggle `wf`; moving (`|dx| > 0.2`) uses sprite `2+wf`, else `1`. Flip when `dx < 0`.
  - Reset when `hy > 128`. Start pose `hx = 2.5`, `hy = 16`.
- `direct/map_data.gd` + `direct/assets/spr_*.png` come from `tools/extract_pico.py`, which decodes
  `__gfx__` / `__map__` in `source/giraffe.p8` (Pico palette, colour 0 transparent on sprites).
  Ground platforms are tile **16**; the decorative floor row is tile **17** (drawn, not solid).
- `direct/game.gd` + `game.tscn` draw a 128×128 room (`cls(0)` + `map(0,0,0,0)` + `spr`), scaled to fit
  with nearest filtering. Arcade `SCALE_MODE` is `letterbox`.

### Deliberate deviations
- **Input:** arrows + WASD (A/D) for walk; Space / Z / X for Pico ❎. Esc is the arcade PauseOverlay only.
- **Debug HUD:** original `print(mget(mx,my+1))` omitted.
- **Commented rect:** the unused bounding-box `rect(...)` is not drawn.

### Not ported
- `__sfx__` / `__music__` / `__gff__` (empty / unused in this cart).
- `tetraminex.p8` / `untitled.p8` from the same repo (tetraminex already has its own arcade tile).

`source/giraffe.p8` is the original cart (`.gdignore`, not exported).

Tests: `tools/test_giraffe.gd` (picked up by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A presentation makeover of the same Pico platformer. **No rules are duplicated:**
`enhanced/game.gd` preloads `direct/giraffe_logic.gd`, `direct/map_data.gd` and the Direct sprites
under `direct/assets/`. Gravity, walk accel/friction, jump, the walk-frame toggle, map collision and the
fall reset are the Direct simulation at the same fixed 30 Hz. Enhanced only reads state after each
`step()` and derives presentation from the deltas, so a rules fix in Direct lands in both editions.
No Alchementrix IP.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | 1280×720 letterbox shell: 5× field, backdrop, side HUD, title card, juice |

### What changed (presentation only)
- **Stage:** fixed 1280×720 stage (`letterbox`). The 128×128 room draws at 5× (640×640) centered,
  with left (stats) and right (controls) panels and a top "Back to Arcade" button (FOCUS_NONE).
- **Backdrop:** savanna dusk sky gradient with twinkling stars, a setting sun and drifting clouds; two
  parallax hill layers with acacia silhouettes rise to the tile-17 décor strip (now with an ember
  shimmer). Below the strip a misty chasm with fireflies and a red danger glow at y=128 marks the
  Direct fall-reset line. Stray clouds/particles are masked to the field.
- **Ledges:** Direct tile-16 art at 5× with a drop shadow and a top highlight. Landing on a ledge
  (a contiguous run of tile 16; the map has 7) lights its top gold.
- **Hero:** same Direct sprites/frames/flip, rendered at 5× with interpolation between 30 Hz steps
  (no lerp across the respawn), squash/stretch anchored at the feet (stretch on jump, squash on land
  scaled by impact), a soft glow, and a ground shadow on the first ledge below that shrinks with height.
- **Juice:** dust on jump / landing / every walk-frame flip; small shake on hard landings; "LEDGE n/7"
  sparkle; fall → "WHOOPS!" floater, flash and respawn sparkle; all ledges → "ALL LEDGES!" toast.
- **HUD:** time, jumps, falls, ledges visited (n/7), best air time, best all-ledges run time. All are
  view-only counters derived from Direct state (the snap condition is re-evaluated read-only).
- **Title card:** Enhanced boots on a title card with the sim idle; Space / Z / X / Enter / arrows /
  A,D start it. Esc opens the arcade PauseOverlay (tree pause freezes the 30 Hz step).

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Rules / sim | `giraffe_logic.gd` + `map_data.gd` | same scripts (preload), no copy |
| Stage | 128×128 scaled to fit, black `cls(0)` | 1280×720 chrome around a 5× (640×640) field |
| Look | nearest-filtered cart sprites | same sprites + dusk backdrop, shadows, squash/stretch, dust, floaters |
| Start | immediately in play | title card, then the same sim |
| Esc / Back | PauseOverlay | same + explicit Back to Arcade (FOCUS_NONE) |

### Deferred
- No new sprites or audio (the cart's `__sfx__` / `__music__` are empty).
- No dedicated Enhanced gallery preview in this PR (card can use the Direct shot).

Tests: `tools/test_giraffe_enhanced.gd` (run by `tools/smoke_headless.sh`): Direct logic ownership,
frame-by-frame parity of a 455-frame scripted session (walks, hops, falls/resets) against a bare Direct
twin, ledge grouping/visits, jump/land/fall juice + counters, all-ledges toast, registry entry, launch +
letterbox, title idles the sim, Space → play, Esc → PauseOverlay freezes the step → Back to Arcade.
