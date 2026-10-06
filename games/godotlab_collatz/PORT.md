# GodotLab collatz: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/godotlab, `collatz/` |
| Source commit | `eca2b0b7bb0e3896e664db6783f67a08b46a7fbc` (master, 2020-11-16) |
| Original | Godot 3 (`config_version=4`): `collatz.tscn`, `bit.tscn`/`bit.gd`, `register.gd`, `adder.tscn`, `bit.svg` |
| License | MIT (`../godotlab/source/LICENSE`). `assets/bit.svg` comes from the same repo |

## What the source was
The source never got past a sketch. `collatz.tscn` has a red `Register` bar (`register.gd` draws
`width*32 × 32`) and a stray bit sprite. `bit.tscn` is a clickable bit: three frames in `bit.svg`
(0 = dark, 1 = light, 2 = faded "unset"), and a click flips it (unset → 1, then 1 ↔ 0).
`adder.tscn` started on a gate with two bits. `collatz.gd` has only two unused exports.

## Direct edition (`direct/`): playable, a completion of the sketch
| Original | Port |
|---|---|
| `bit.tscn` / `bit.gd` | Same frames, the same toggle rule on mouse release, and the same Area2D circle (r 10 × scale 3 baked to r 30). It also emits `toggled` |
| `register.gd` (`tool`, `export(int) width`) | `@tool`, `@export var width`. Draws the same `Color.RED` bar |
| `collatz.tscn` (Register at (90,140)) | `game.tscn`. The Register is under a 2× `World` with `width = 16` |
| `collatz.gd` (empty) | `collatz.gd`, the stepper (below) |

The port finishes the evident intent: `width` clickable bits sit on the Register, with bit 0 on the
right. One Collatz step is `n >> 1` for even n and `3n + 1` for odd n. Faded (unset) bits read as 0.
The HUD shows n, the step count, the peak, and the trail. If a step would overflow 16 bits, it's refused
with a message. The test checks n = 27, which reaches 1 in 111 steps with a peak of 9232.

### Deliberate deviations
- The stepper logic, HUD, buttons, and keys (Space/Enter/→ step, R run, C/Backspace clear) are **new**. The source had none.
- Dropped: the stray `bit` sprite in `collatz.tscn` (it had `hframes = 2` on a 3-frame sheet and sat under
  the bar), `adder.tscn` (an unfinished gate), and `collatz.gd`'s unused `sprite`/`resource` exports
  (the `resource` was a 3D `PlaneShape`).
- Godot 4 picking: the scene turns on `physics_object_picking` for the bits and restores the previous value when it exits.
- **Esc** opens the arcade PauseOverlay.

### Todos
- Enhanced edition: not started. It could animate the shift and the 3n+1 = (n<<1)+n+1 adder, which was where `adder.tscn` was heading.
