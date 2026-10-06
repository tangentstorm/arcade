# Bullet Demo: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/GameSketchLib, `course/w02_InvaderSketch/demos/BulletDemo/BulletDemo.pde` |
| Source commit | `6b0de14f3db9cac10be00b00a0a879cd943c4c32` (master, 2020-11-16) |
| License | Course code: **CC-BY 3.0** © Michal J. Wallace (GameSketchLib itself: MIT © 2011 Michal J. Wallace). Copy in `source/LICENSE.txt`. |
| Original | Processing / processing.js sketch, 300×300, ~2011. A GameSketchLib course week-2 tech demo, not a full game |

## Direct edition (`direct/`): playable

Click to fire one of three yellow bullets straight up from the mouse x. A bullet that hits a live square kills it, and the square turns light gray (#CCCCCC). Spent bullets go back to the ammo rack in the bottom-left corner. There's no win state.

- `direct/bullet_logic.gd` is a line-for-line port of the `.pde`. One `step()` is one Processing `draw()` frame, at Processing's default 60 fps. `render()` returns the frame as a small draw list (`bg` / `rect` / `text`).
- `direct/game.gd` + `game.tscn` scale the 300×300 sketch to fit, forward input as Processing events, and paint the draw list.

### Faithful quirks kept
- **The ammo rack is the dead bullets.** They sit at `(10·i, 280)` and draw there.
- **Fire position:** the bullet's *left* edge is at the mouse x, and it starts at y = 260 (`height - 2·kBulletH`).
- **3.75 px/frame**, with movement before collision, so one bullet can kill two squares in one frame if it overlaps both. Dead squares no longer collide.
- **Clicks are rationed by `mBulletsLeft`**, which only refreshes in `update()`. Several clicks between frames can't fire more than the rack holds.
- When nothing is free, `nextBullet()` falls back to bullet 0. That's unreachable in practice because of the rack count.

### Deliberate deviations
- **Clock:** a fixed 60 Hz step from an accumulator (max 0.25 s of catch-up) stands in for Processing's `draw()` loop.
- **Scaling:** the 300×300 sketch scales to fit the window (letterbox). A small controls hint sits in the margin, outside the sketch.
- **Strokes:** rects get Processing's default 1 px black stroke, drawn as a Godot outline.
- **Esc** opens the arcade PauseOverlay. In Processing, Esc quit the sketch.
- **Mouse:** a press only reaches the sketch if it lands on the 300×300 canvas. Drags keep reporting once a button is held, even outside it, as in Java Processing.
- **Text** (if any) uses Godot's default font at the original pixel size, in place of Processing's default sans.

`source/` holds the original `.pde` and `LICENSE.txt` for reference. It has a `.gdignore`, so Godot doesn't import it.

Tests: `tools/test_gsl_demos.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition: planned (not started)
