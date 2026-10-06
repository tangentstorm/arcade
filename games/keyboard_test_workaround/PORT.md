# Keyboard Test (Workaround): port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/GameSketchLib, `course/w02_InvaderSketch/keyboard_tests/KeyboardTestWorkaround/KeyboardTestWorkaround.pde` |
| Source commit | `6b0de14f3db9cac10be00b00a0a879cd943c4c32` (master, 2020-11-16) |
| License | Course code: **CC-BY 3.0** © Michal J. Wallace (GameSketchLib itself: MIT © 2011 Michal J. Wallace). Copy in `source/LICENSE.txt`. |
| Original | Processing / processing.js sketch, 300×300, ~2011. A GameSketchLib course week-2 tech demo, not a full game |

## Direct edition (`direct/`): playable

Two 4-key pads on black: WASD (plus the Dvorak equivalents `,` `A` `O` `E`) on the left, and the arrow keys on the right. A held key lights up white. It's the fixed version of KeyboardTestBuggy: `if (key == CODED)` replaces `switch(key) … case CODED`.

- `direct/kb_workaround_logic.gd` is a line-for-line port of the `.pde`. One `step()` is one Processing `draw()` frame, at Processing's default 60 fps. `render()` returns the frame as a small draw list (`bg` / `rect` / `text`).
- `direct/game.gd` + `game.tscn` scale the 300×300 sketch to fit, forward input as Processing events, and paint the draw list.

### Faithful quirks kept
- **Every keyPressed *and* keyReleased XOR-toggles the key's bit.** So OS key-repeat (extra keyPressed events) makes a held key flicker, and a missed release leaves a key lit. That's the problem the HashMap version solves.
- `,`/`<` and `W` both drive north. Shift doesn't matter (both cases are listed).

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
