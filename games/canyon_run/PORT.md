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

## Enhanced edition — planned
Visual polish and an asset or layout scrape from the Claude Design demo are
**deferred to Enhanced**. That work starts once someone with a signed-in session
extracts the Design page (HTML/CSS, palette, sprites, HUD layout) into the repo.
Enhanced should then match the Design, and can add fuel, bridges and audio.

Tests: `tools/test_canyon_run.gd` (picked up by `tools/smoke_headless.sh`).
