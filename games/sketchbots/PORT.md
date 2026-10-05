# SketchBots — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/GameSketchLib, `course/w01_SketchBots/demos/SketchBots/` |
| Source commit | `6b0de14f3db9cac10be00b00a0a879cd943c4c32` (master, 2020-11-16) |
| License | Course (game code + sprites): **CC-BY 3.0** © Michal J. Wallace. Copy in `source/LICENSE.txt`. |
| Original | Processing / processing.js sketch, 300×300, ~160 lines (week-1 hello-world) |

## Direct edition (`direct/`) — playable

- `direct/sketchbots_logic.gd` ports `SketchBots.pde`: heading bitflags (`NORTH|EAST|SOUTH|WEST`),
  10 px/frame movement (including full-speed diagonals), bottom-only clamp, and the
  `keyPressed`/`keyReleased` image + heading updates.
- One `step()` is one Processing `draw()` frame. The sketch sets `frameRate(30)`, so the
  caller steps at a fixed 30 Hz.
- `direct/game.gd` + `game.tscn` draw the 300×300 sketch scaled to fit: background at (0,0),
  orange guy at `(orange_x, orange_y)`, blue guy fixed at bottom-centre facing down.
- `direct/assets/` holds the original PNGs used by the demo (`background.png`,
  `orangeguy-{U,D,L,R}.png`, `blueguy-D.png`).

### Faithful quirks kept
- **Only the bottom edge clamps.** Orange can leave the top, left, and right of the 300×300
  canvas (and clip_contents hides him until he comes back).
- **Diagonals are not normalised.** Holding north+east moves 10 px on both axes per frame.
- **Opposing directions cancel.** `NORTH|SOUTH` (and `EAST|WEST`) match no `switch` case, so
  the sprite stands still while both bits stay set.
- **Key release uses XOR (`^=`).** Same as the original: a mismatched release can flip a bit
  on instead of clearing it.
- **Facing follows the last non-arrow press.** Arrow-Up sets the north bit but does not change
  the sprite image. WASD and Dvorak `,aoe` (plus `<` / case variants) do.
- **Background is 900×300.** Drawn at (0,0); only the left 300×300 is visible in the canvas.
- **Starts centred, facing left** (`mOrangeGuyL`), with blue guy at the bottom centre.

### Deliberate deviations
- **Esc** opens the arcade PauseOverlay (pause, or Back to Arcade). Pausing the tree freezes
  the simulation.
- **Help text:** a small controls hint sits in the letterbox margin, outside the 300×300 sketch.
- **Clock:** a fixed 30 Hz step from an accumulator (max 0.25 s of catch-up) stands in for
  Processing's `draw()` loop.
- **Pixel filtering:** sprites scale with nearest-neighbour filtering.

### Not ported
- The commented-out `Sprite` class sketch in the `.pde` (teaching note only).
- Unused sheet strips (`orangeguy.png`, `blueguy.png`) and unused blueguy direction frames;
  they remain under `source/data/` for reference.

`source/` holds the original `SketchBots.pde`, `data/`, and `LICENSE.txt`. It has a
`.gdignore`, so Godot doesn't import it.

Tests: `tools/test_sketchbots.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition — planned (not started)
