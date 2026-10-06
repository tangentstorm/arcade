# Keyboard Test (Buggy): port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/GameSketchLib, `course/w02_InvaderSketch/keyboard_tests/KeyboardTestBuggy/KeboardTestBuggy.pde` |
| Source commit | `6b0de14f3db9cac10be00b00a0a879cd943c4c32` (master, 2020-11-16) |
| License | Course code: **CC-BY 3.0** © Michal J. Wallace (GameSketchLib itself: MIT © 2011 Michal J. Wallace). Copy in `source/LICENSE.txt`. |
| Original | Processing / processing.js sketch, 300×300, ~2011. A GameSketchLib course week-2 tech demo, not a full game |

## Direct edition (`direct/`): playable

The broken first keyboard test. It's the same two pads as the Workaround, but the arrow keys sit under `switch(key) { … case(CODED): … }`, which **never matched in processing-js**, the runtime the sketch was published on (studio.sketchpad.cc). The WASD/Dvorak pad works and the arrow pad stays dark.

- `direct/kb_buggy_logic.gd` is a line-for-line port of the `.pde`. One `step()` is one Processing `draw()` frame, at Processing's default 60 fps. `render()` returns the frame as a small draw list (`bg` / `rect` / `text`).
- `direct/game.gd` + `game.tscn` scale the 300×300 sketch to fit, forward input as Processing events, and paint the draw list.

### Faithful quirks kept
- **The bug is kept on purpose** (`EMULATE_PJS_BUG = true` in the logic): arrows do nothing, and the dead `probe` string never changes. In desktop Java Processing the switch would have worked. The tile shows what the course demonstrated.
- **The source file doesn't compile as committed.** `KeboardTestBuggy.pde` (sic) holds the sketch twice, separated by a stray line, ` KeyboardTest : processing-js bug`. The port uses the first copy. The two copies differ only in the header comment.
- Same XOR flicker on key-repeat as the Workaround.

### Deliberate deviations
- **Clock:** a fixed 60 Hz step from an accumulator (max 0.25 s of catch-up) stands in for Processing's `draw()` loop.
- **Scaling:** the 300×300 sketch scales to fit the window (letterbox). A small controls hint sits in the margin, outside the sketch.
- **Strokes:** rects get Processing's default 1 px black stroke, drawn as a Godot outline.
- **Esc** opens the arcade PauseOverlay. In Processing, Esc quit the sketch.
- **Keys:** Godot key events become Processing `(key, keyCode)` pairs. Arrows, Shift, Ctrl and Alt are `CODED` (keyCodes 37–40, 16–18). Printable keys use the typed character. Releases rebuild letters from the Shift state, as Java's `getKeyChar()` does.
- **Key repeat:** OS auto-repeat is delivered as extra `keyPressed` events, as Processing did.
- **Text** (if any) uses Godot's default font at the original pixel size, in place of Processing's default sans.

`source/` holds the original `.pde` and `LICENSE.txt` for reference. It has a `.gdignore`, so Godot doesn't import it.

Tests: `tools/test_gsl_demos.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition: planned (not started)
