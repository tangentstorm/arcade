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

## Enhanced edition — planned (not started)
