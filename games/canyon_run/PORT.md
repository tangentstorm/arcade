# Canyon Run — port notes

| | |
|---|---|
| Tracking | https://github.com/tangentstorm/arcade/issues/36 |
| Design reference | Claude Design UI mock (signed-in): https://claude.ai/design/p/af9ffe73-f0c0-4468-9702-76df5f564857?file=Michal+J+Wallace.dc.html&via=share |
| Design screenshots / script | Box path `/workspace/canyon-run-design/` — `02-expanded-banner-full-page.png`, `03-expanded-canyon-closeup.png`, `04-island-detail.png`; extracted draw script `source/canyon-run.dc-script.js` + `geometry-notes.json` |
| Source repo | none — there is no standalone Canyon Run codebase |
| Engine | Godot 4.7 (GDScript), original arcade rules + Design-mock visuals |

## Source reality
The Design mock lives on Claude Design (signed-in browser). Screenshots and the
verbatim `canyon-run.dc-script.js` draw/generation script are captured under
`/workspace/canyon-run-design/`. Terrain is **procedural** (no fixed vertex arrays);
Godot ports the mock **algorithm** (6 contour bands, palette, wave layers, jet/boat
sprites, visual islands). Arcade rules stay in `canyon_logic.gd` (tests depend on them).

## Direct edition (`direct/`) — playable MVP
- **Stage:** 240×320 portrait, drawn at 2× (480×640) centred in the 1280×720 base
  viewport. `SCALE_MODE` = `letterbox` (KEEP + integer stretch), so the stage stays
  crisp with bars around it. HUD (score / best / speed) sits right; help text and a
  "Back to Arcade" button sit left.
- `direct/canyon_logic.gd`: node-free simulation (testable headless).
  - Coastline (band-0) uses the Design genRow walk (`dy` 95..180, hold-flat 0.2,
    centre ±0.085 clamp 0.36..0.64, width ±0.1 clamp 0.3..0.68, normalized l/r).
    `walls_at` interpolates those sparse rows into stage px — collision = waterline.
  - Craft fixed at screen y 280; steer 110 px/s; throttle 40 / 70 / 120 px/s
    (slow / cruise / fast).
  - Fire: twin orange darts every 0.18 s (±0.028 width), killed by walls or leaving the top.
  - Red drifters spawn above the top edge in the channel and bounce wall to wall.
    Shot = +50; ramming one crashes. Drawn as red/white gunboats.
  - Score = distance / 10 + 50 per kill. Best is kept across runs.
  - Wall or drifter contact → CRASHED; after a 1 s hold, Space/Z resets to READY.
- `direct/canyon_topo.gd`: paper-cut topo renderer ported from the Design script.
  - Palette (water→out): `#6b4f36` … `#f0dcae` (6 bands); water `#7ba7c2`→`#3d6b87`.
  - Band 0 coastline = `logic.coast_rows` (same Design rows as collision). Bands 1–5
    use the mock's genRow walk + scroll rates `1.0 … 1.45×`, clamped inland of the coast
    with `minGap = i*0.014`.
  - Scalloped wave lines (3 layers), nested mid-river islands (visual-only), grey jet
    with orange/yellow afterburners, striped boats, CANYON RUN + WIP badge.
- `direct/game.gd` + `game.tscn`: input, topo `_draw()`, labels.
- Esc is the arcade PauseOverlay (resume / Back to Arcade).

### Not in the MVP (deliberately)
- **Fuel** (River Raid fuel depots and gauge): optional for the MVP and left out.
- Bridges, sections or checkpoints, lives, sound, touch controls.
- Island / heli collision (islands are visual-only; enemies stay Direct drifters).

Tests: `tools/test_canyon_run.gd` (picked up by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A letterbox shell over the same Direct sim + shared `canyon_topo.gd` field paint.
**No rules are duplicated:** `enhanced/game.gd` preloads Direct `canyon_logic.gd`.
Steer, throttle, fire, canyon generation, drifters, scoring and crash/reset stay
Direct. Enhanced wraps the sim in a 1280×720 shell and derives juice from state
deltas (new bullets, kill count, READY→PLAY→CRASHED).

### Visuals / UI
- 1280×720 letterbox stage; Direct 240×320 portrait @2× (480×640) in a clipped field
  between left/right HUD panels
- Field: same Design-mock topo as Direct (shared `canyon_topo.gd`)
- Juice: fading wake trail, muzzle / kill bursts, crash shake + flash + crash card
- Left HUD: title, controls, Back to Arcade (`FOCUS_NONE`). Right HUD: score / best /
  dist / speed / kills / channel width + throttle bar
- Title card on boot (Space/Enter/Start); Esc → PauseOverlay

### Scope honesty
- Visual parity targets the Claude Design mock (screenshots + extracted draw script
  under `/workspace/canyon-run-design/`). Rules stay the arcade Direct sim.
- Still no fuel, bridges, lives, sound or touch controls (those need rules or assets).

### Behaviour notes
- Input map matches Direct (←/→ A/D, ↑/↓ W/S, Space/Z fire + restart after crash hold).
- Title card holds READY until Start; then Direct `start()` / `update` run as usual.
- Esc → PauseOverlay. Title `scale_mode` stays `letterbox`.
- No Alchementrix IP. No `_enhanced` preview yet (gallery can use the Direct shot).

Tests: `tools/test_canyon_run_enhanced.gd` (run by `tools/smoke_headless.sh`).
