# Overlap Demo: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/GameSketchLib, `course/w02_InvaderSketch/demos/OverlapDemo/OverlapDemo.pde` |
| Source commit | `6b0de14f3db9cac10be00b00a0a879cd943c4c32` (master, 2020-11-16) |
| License | Course code: **CC-BY 3.0** © Michal J. Wallace (GameSketchLib itself: MIT © 2011 Michal J. Wallace). Copy in `source/LICENSE.txt`. |
| Original | Processing / processing.js sketch, 300×300, ~2011. A GameSketchLib course week-2 tech demo, not a full game |

## Direct edition (`direct/`): playable

Drag the nine white squares around a blue 300×300 canvas. Any square that overlaps another turns gray. It's the first step of the InvaderSketch tutorial (collision boxes).

- `direct/overlap_logic.gd` is a line-for-line port of the `.pde`. One `step()` is one Processing `draw()` frame, at Processing's default 60 fps. `render()` returns the frame as a small draw list (`bg` / `rect` / `text`).
- `direct/game.gd` + `game.tscn` scale the 300×300 sketch to fit, forward input as Processing events, and paint the draw list.

### Faithful quirks kept
- **Grabbing a stack takes the lowest-index square**, even though higher-index squares are drawn on top of it.
- **Edges that only touch don't overlap** (strict `<` in `overlaps()`).
- **Squares can be dragged off the canvas** and lost. Nothing clamps them.
- The overlap scan is the full n² loop, and colours are final before each square renders, so a single post-step render list matches the original's render-inside-the-loop.

### Deliberate deviations
- **Clock:** a fixed 60 Hz step from an accumulator (max 0.25 s of catch-up) stands in for Processing's `draw()` loop.
- **Scaling:** the 300×300 sketch scales to fit the window (letterbox). A small controls hint sits in the margin, outside the sketch.
- **Strokes:** rects get Processing's default 1 px black stroke, drawn as a Godot outline.
- **Esc** opens the arcade PauseOverlay. In Processing, Esc quit the sketch.
- **Mouse:** a press only reaches the sketch if it lands on the 300×300 canvas. Drags keep reporting once a button is held, even outside it, as in Java Processing.
- **Text** (if any) uses Godot's default font at the original pixel size, in place of Processing's default sans.

`source/` holds the original `.pde` and `LICENSE.txt` for reference. It has a `.gdignore`, so Godot doesn't import it.

Tests: `tools/test_gsl_demos.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A presentation makeover of the same nine-square sketch. **No rules are duplicated:**
`enhanced/game.gd` instances Direct `game.tscn` (shared `overlap_logic.gd` + `game.gd`
input mapping) in a SubViewport. The n² overlap scan, strict-`<` edges, lowest-index grab,
unclamped drags and the fixed 60 Hz step all stay Direct. Enhanced only frames the sketch
and derives juice from watching Direct square colours / `in_hand` / positions. No
Alchementrix IP.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | 1280×720 letterbox shell: 2× field, juice layer, HUD, title card |

### What changed (presentation only)
- **Stage:** fixed 1280×720 stage (`letterbox`). Direct runs in a native **300×300 SubViewport**
  shown @2× (600×600) via `SubViewportContainer.stretch = false` + `scale = 2` (nearest
  filter, crisp pixels). Not `stretch = true`: that resizes the SubViewport and breaks the
  juice mapping (the Overlap #78 lesson). Direct's own margin hint is hidden (Enhanced HUD
  replaces it).
- **Juice (Fx layer above the SubViewport):** hatched, pulsing overlap zones (the intersection
  of each overlapping pair), pulsing outline on gray squares, gold outline + alignment guides on
  the held square, green hint on the square a press would grab (the lowest index, explaining
  the Direct quirk), grab/drop rings, OVERLAP / clear bursts + floaters, first-overlap banner +
  flash + light shake, LOST burst and edge arrows pointing at off-canvas squares.
- **HUD:** gray count, overlap zones, held square #/position, mouse in sketch px, grabs, overlap
  events / peak gray, off-canvas count, colour legend.
- **Title card** on boot (Start / Space / Enter, Back to Arcade); Direct is frozen
  (`PROCESS_MODE_DISABLED`) and click-blocked behind it. **R** reloads a fresh Direct scene.
  Back to Arcade buttons are `FOCUS_NONE`. Esc → PauseOverlay.

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Overlap / drag rules | `direct/overlap_logic.gd` | same scene (instance), no copy |
| Stage | 300×300 scaled to window | 1280×720 chrome around a 300×300 SubViewport @2× |
| Start | sketch live immediately | title card, then the same Direct sketch |
| Help | margin label | side HUD + legend (Direct label hidden) |
| Esc / Back | PauseOverlay | same + explicit Back (FOCUS_NONE) |

### Deferred
- Dedicated `_enhanced` gallery preview (card can use the Direct shot)

Tests: `tools/test_overlap_demo_enhanced.gd` (run by `tools/smoke_headless.sh`): no-rules-copy
scan, registry, title/buttons, SubViewport size/stretch/scale and Fx layering, real mouse
grab/drag/off-canvas through the Enhanced stage vs a bare Direct logic twin (squares + render
list), overlap/clear/lost juice + HUD, R reset, Esc → PauseOverlay → arcade.
