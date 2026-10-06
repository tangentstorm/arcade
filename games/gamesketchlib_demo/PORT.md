# GameSketchLib Demo: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/GameSketchLib, `course/w02_InvaderSketch/demos/GameSketchLibDemo/GameSketchLibDemo.pde` |
| Source commit | `6b0de14f3db9cac10be00b00a0a879cd943c4c32` (master, 2020-11-16) |
| License | Course code: **CC-BY 3.0** © Michal J. Wallace (GameSketchLib itself: MIT © 2011 Michal J. Wallace). Copy in `source/LICENSE.txt`. |
| Original | Processing / processing.js sketch, 300×300, ~2011. A GameSketchLib course week-2 tech demo, not a full game |

## Direct edition (`direct/`): playable

BulletDemo rebuilt on the first cut of the GameSketchLib engine (flixel-style GameBasic/GameObject/GameGroup/GameState plus a `Game` singleton), with a click-to-start menu. Clearing all nine squares goes back to the menu. (The file's header comment still says "BulletDemo".)

- `direct/gsl_demo_logic.gd` is a line-for-line port of the `.pde`. One `step()` is one Processing `draw()` frame, at Processing's default 60 fps. `render()` returns the frame as a small draw list (`bg` / `rect` / `text`).
- `direct/game.gd` + `game.tscn` scale the 300×300 sketch to fit, forward input as Processing events, and paint the draw list.

### Faithful quirks kept
- **Dead squares still soak up bullets.** `GameGroup.overlap()` checks `active`/`exists` but never `alive`, and a hit only clears `alive`. A gray square keeps absorbing shots, so you have to aim at live columns.
- **The overlap check runs *before* the bullets move**, so a fresh shot collides one frame later than in BulletDemo.
- Clicks fire `firstDead()` with no rack limit, but there are still only three bullets.
- The menu is black (GameState's default `bgColor`); play is #3366FF. The prompt is 16 px white text at (10, 50), left-aligned on the baseline.

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

A visual/UI makeover of the same BulletDemo-on-GameSketchLib tech demo. **No rules
are duplicated:** `enhanced/game.gd` preloads Direct `gsl_demo_logic.gd` and paints
its `render()` list. The click-to-start menu, `firstDead()` firing from mouse x,
three bullets, overlap-before-move, dead squares that still soak up bullets, and
clear-the-board → menu all stay Direct. Enhanced only wraps the sim in a 1280×720
letterbox shell and derives juice from state deltas (bullet fired / died, square
killed, menu ⇄ play switches).

### Visuals / UI
- 1280×720 letterbox stage; Direct 300×300 sketch @2× (600×600) in a clipped
  field between left/right gutter HUD panels
- Stage gradient + neon frame. Direct's black menu gets drifting specks and a
  glowing copy of the Direct prompt (same text, position, 16 px @2×); Direct's
  #3366FF play field gets a light-from-above wash, faint grid, and a rack shelf
- Direct rects with glow: live squares pulse, dead squares go cracked gray (still
  solid), bullets glow gold with motion trails; Processing's 1 px black stroke @2×
- Juice: muzzle burst + ring on fire, white/gold burst + "HIT" + shake/flash on a
  kill, steel ping + "SOAK" when a dead square absorbs a shot, fizzle when a bullet
  leaves the top, "EMPTY" on a click with no bullet racked, "GO!" on start,
  "BOARD CLEAR!" burst if Direct switches back to the menu
- Aim guide (view-only): dashed lane from the launch slot at mouse x up to the
  first square it would meet: green bracket = live target, gray X = dead square
  that will soak the shot
- Left HUD: title, controls, quirk notes, Back to Arcade (`FOCUS_NONE`). Right
  HUD: menu/play state, rack meter, live squares, shots / hits / soaked / missed,
  boards cleared (view-only)
- Title card on boot (Space/Enter/Start, `FOCUS_NONE`); Esc → PauseOverlay

### Behaviour notes
- Input matches Direct: mouse presses on the 300×300 field reach `mouse_pressed`
  in sketch coords (field px ÷ 2); releases/drags are forwarded too (Direct no-ops).
- Title card freezes the sim until Start; then `world.step` runs at Direct's 60 Hz.
  After Start you see Direct's own black menu and click to begin, as in Direct.
- Only the bottom row can be shot: a dead bottom square soaks every later bullet in
  its column (Direct quirk, kept). The aim guide and SOAK juice make that readable.
- Esc → PauseOverlay. Title `scale_mode` stays `letterbox`.
- No Alchementrix IP. No `_enhanced` preview yet (gallery can use the Direct shot).

Tests: `tools/test_gamesketchlib_demo_enhanced.gd` (run by `tools/smoke_headless.sh`).
