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
  `keyPressed`/`keyReleased` image + heading updates — now for **both** orange and blue.
- One `step()` is one Processing `draw()` frame. The sketch sets `frameRate(30)`, so the
  caller steps at a fixed 30 Hz.
- `direct/game.gd` + `game.tscn` draw the 300×300 sketch scaled to fit: background at (0,0),
  orange guy at `(orange_x, orange_y)`, blue guy at `(blue_x, blue_y)` with facing sprites.
- `direct/assets/` holds the original PNGs used by the demo (`background.png`,
  `orangeguy-{U,D,L,R}.png`, `blueguy-{U,D,L,R}.png`).

### Faithful quirks kept
- **Only the bottom edge clamps.** Either guy can leave the top, left, and right of the 300×300
  canvas (and clip_contents hides them until they come back).
- **Diagonals are not normalised.** Holding north+east moves 10 px on both axes per frame.
- **Opposing directions cancel.** `NORTH|SOUTH` (and `EAST|WEST`) match no `switch` case, so
  the sprite stands still while both bits stay set.
- **Key release uses XOR (`^=`).** Same as the original: a mismatched release can flip a bit
  on instead of clearing it. Applied independently per player.
- **Background is 900×300.** Drawn at (0,0); only the left 300×300 is visible in the canvas.
- **Orange starts centred, facing left** (`mOrangeGuyL`); blue starts at bottom centre facing down.

### Deliberate deviations
- **Two-player (teaching exercise).** The original only moved orange (`mOrangeGuy*`); blue was
  drawn fixed at bottom-centre, and Arrow-Up was wired to orange north without changing his
  face. The PDE comment invites the adventurous to "make orange and blue guys into sprites."
  This port does that: orange keeps WASD + Dvorak `,aoe` (and `<`); blue gets all four arrow
  keys with facing sprites. Same SPEED / bitflag / step / bottom-clamp / XOR-release quirks
  apply to both.
- **Esc** opens the arcade PauseOverlay (pause, or Back to Arcade). Pausing the tree freezes
  the simulation.
- **Help text:** ASCII-only controls hint in the letterbox margin (no Unicode arrows — missing
  in the default font).
- **Clock:** a fixed 30 Hz step from an accumulator (max 0.25 s of catch-up) stands in for
  Processing's `draw()` loop.
- **Pixel filtering:** sprites scale with nearest-neighbour filtering.

### Not ported
- The commented-out `Sprite` class sketch in the `.pde` (teaching note only; the 2P split
  above is the intended exercise).
- Unused sheet strips (`orangeguy.png`, `blueguy.png`); they remain under `source/data/` for
  reference.

`source/` holds the original `SketchBots.pde`, `data/`, and `LICENSE.txt`. It has a
`.gdignore`, so Godot doesn't import it.

Tests: `tools/test_sketchbots.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition — planned (not started)
