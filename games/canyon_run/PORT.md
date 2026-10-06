# Canyon Run — port notes

| | |
|---|---|
| Tracking | https://github.com/tangentstorm/arcade/issues/36 |
| Design reference | Claude Design UI mock (signed-in only): https://claude.ai/design/p/af9ffe73-f0c0-4468-9702-76df5f564857?file=Michal+J+Wallace.dc.html&via=share |
| Source repo | none — there is no standalone Canyon Run codebase |
| Engine | Godot 4.7 (GDScript), original code written for this arcade |

## Source reality
The only artifact is a demo-only UI mock on Claude Design, which needs a signed-in
browser and was **not** available when this Direct was built. Nothing (art, layout,
palette, numbers) was scraped from it. This Direct is a clean, original Godot 4
build of the genre: a modern River Raid–style vertical canyon flyer.

## Direct edition (`direct/`) — playable MVP
- **Stage:** 240×320 portrait, drawn at 2× (480×640) centred in the 1280×720 base
  viewport. `SCALE_MODE` = `letterbox` (KEEP + integer stretch), so the stage stays
  crisp with bars around it. HUD (score / best / speed) sits right; help text and a
  "Back to Arcade" button sit left.
- `direct/canyon_logic.gd`: node-free simulation (testable headless).
  - Procedural canyon sampled every 4 world px: a 60-row straight runway at width 170,
    then the channel narrows with distance (floor 70 px) with a slow sine pinch, and
    its centre eases toward a new random target every 45 rows. Seeded RNG; rows below
    the screen are pruned.
  - Craft fixed at screen y 280; steer 110 px/s; throttle 40 / 70 / 120 px/s
    (slow / cruise / fast).
  - Fire: bullets every 0.18 s, killed by walls or leaving the top.
  - Red drifters spawn above the top edge in the channel and bounce wall to wall.
    Shot = +50; ramming one crashes.
  - Score = distance / 10 + 50 per kill. Best is kept across runs.
  - Wall or drifter contact → CRASHED; after a 1 s hold, Space/Z resets to READY.
- `direct/game.gd` + `game.tscn`: input, `_draw()` with flat-colour rects/polygons, labels.
- Esc is the arcade PauseOverlay (resume / Back to Arcade).

### Not in the MVP (deliberately)
- **Fuel** (River Raid fuel depots and gauge): optional for the MVP and left out.
- Bridges, sections or checkpoints, lives, sound, touch controls.
- Any visual polish or assets from the Design mock.

Tests: `tools/test_canyon_run.gd` (picked up by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A visual/UI makeover of the same River Raid–style flyer. **No rules are duplicated:**
`enhanced/game.gd` preloads Direct `canyon_logic.gd`. Steer, throttle, fire, canyon
generation, drifters, scoring and crash/reset stay Direct. Enhanced only wraps the
sim in a 1280×720 letterbox shell and derives juice from state deltas (new bullets,
kill count, READY→PLAY→CRASHED).

### Visuals / UI
- 1280×720 letterbox stage; Direct 240×320 portrait @2× (480×640) in a clipped field
  between left/right HUD panels (same resolution as Direct, richer chrome)
- Layered canyon: deep rock fill, mid cliff band, lit rim, occasional ledge notches,
  foam at the water edge; river depth gradient + drifting shimmer
- Craft: glow disc, speed-scaled exhaust plume + cyan/gold sparks, fading wake trail;
  crashed craft tints red
- Bullets as glowing tracers with muzzle burst; drifters with pulse halo + highlight
- Kill juice: burst + floating "+50"; crash: shake, hot flash, debris, crash card
- Left HUD: title, controls, Back to Arcade (`FOCUS_NONE`). Right HUD: score / best /
  dist / speed / kills / channel width + throttle bar
- Title card on boot (Space/Enter/Start); Esc → PauseOverlay

### Scope honesty
- Claude Design exact parity is **out of scope** without reference screenshots; this
  edition is an original River Raid–style polish over Direct.
- Still no fuel, bridges, lives, sound or touch controls (those need rules or assets).

### Behaviour notes
- Input map matches Direct (←/→ A/D, ↑/↓ W/S, Space/Z fire + restart after crash hold).
- Title card holds READY until Start; then Direct `start()` / `update` run as usual.
- Esc → PauseOverlay. Title `scale_mode` stays `letterbox`.
- No Alchementrix IP. No `_enhanced` preview yet (gallery can use the Direct shot).

Tests: `tools/test_canyon_run_enhanced.gd` (run by `tools/smoke_headless.sh`).
