# GodotLab game01: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/godotlab, `game01/` (project name `game02`) |
| Source commit | `eca2b0b7bb0e3896e664db6783f67a08b46a7fbc` (master, 2020-11-16) |
| Original | Godot 3 (`config_version=4`, GLES2, fullscreen), `main.tscn` + `hero.gd` + `crosshair.gd` |
| License | MIT (`../godotlab/source/LICENSE`). The art (`hero.png`, `crosshair.png`, `fireball.png`) is from the same repo |

The committed Godot 3 HTML5 export (`export/html5/game02.*`) was checked. Its `.pck` has the same
`main.tscn`/`hero.gdc`/`crosshair.gdc`/`fireball.png` as the source tree, so there's no newer code hiding in it.
It isn't vendored.

## Direct edition (`direct/`): playable

| Original | Port |
|---|---|
| `main.tscn` (root `Scene` scaled 2×, with hero, crosshair, and fireball) | `direct/game.tscn`. Same nodes, positions, and 2× scale under a `Scene` node |
| `hero.gd` | `direct/hero.gd`. 10 px/frame movement, and the crosshair drifts with the hero |
| `crosshair.gd` | `direct/crosshair.gd`. Hidden OS cursor, and the crosshair follows mouse *motion* deltas |

### How it was migrated
- `Sprite` → `Sprite2D`.
- **Facing:** Godot 3's `a.angle_to_point(b)` returned the angle of `a - b`. Godot 4 reversed that.
  The art faces −x, so `rotation = (position - crosshair.position).angle()` keeps the nose on the
  crosshair, as in the original.
- `get_global_mouse_position() / 2` → `get_parent().get_local_mouse_position()` (same value under the 2× root).

### Deliberate deviations
- **Keys:** the original polled the *logical* Dvorak keys `,` `A` `O` `E`, which sit at the W A S D positions on
  a Dvorak board. The port polls the *physical* W A S D positions, so the layout stays the same for a
  Dvorak typist and also works on QWERTY. The arrow keys are added too.
- **Fixed tick:** movement runs in `_physics_process` (60 Hz) instead of `_process`, as in game00.
- **Crosshair clamp:** the crosshair is clamped to the screen. In the original it could drift off-screen while the hero walked.
- **Cursor hygiene:** the OS cursor comes back while the arcade is paused and when you leave the game.
  The startup `warp_mouse` was dropped, because browsers forbid it and the original passed a local position anyway.
- The fireball is still a static prop, as in the original. Nothing fires it.
- **HUD hint label.** **Esc** opens the arcade PauseOverlay. The original was fullscreen with no exit.

### Todos
- Enhanced edition: not started. Throwing the fireball at the crosshair is the obvious next step.
