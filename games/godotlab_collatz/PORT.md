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

## Enhanced edition (`enhanced/`): playable

A visual/UI makeover of the same stepper. **Nothing is re-implemented:** `enhanced/game.gd`
preloads Direct `game.tscn` and instances it as-is (shared `collatz.gd`, `bit.gd`, `register.gd`),
so the bits, the click toggle, the keys (Space/Enter/→ step, R run, C/Backspace clear), Run's
0.25 s cadence and the 16-bit overflow refusal are all Direct. Enhanced hides Direct's plain
`Hud` labels/buttons, slides the scene so the register sits in its field, and draws on top.

### Visuals / UI
- 1280×720 designed stage, self-fitted to the window (title `scale_mode` stays `expand`, as for
  Direct); dark gradient with drifting 0/1 dust; the Direct red register bar slightly muted via
  `self_modulate`
- Register field: bit index above and place value (2^i) below each cell, gold glow on set bits,
  a flip ring + sparks on every bit that changes, hover tooltip `bit i · 2^i = v`, RUNNING lamp
- **Step animation:** on a halving the set bits slide one cell right; on 3n+1 an orange ripple
  sweeps LSB → MSB across the register
- **Last-step panel:** `n` and `n >> 1` with the old row sliding away, or `n<<1 + n + 1 = 3n+1`
  in binary with the carries revealed as a ripple
- **Trajectory chart:** log₂ n per step (orange rises, blue falls), peak marker, pulsing current point
- Reached 1: rainbow sparks + flash + banner. Overflow: shake + red flash + banner
- HUD: n (dec / hex / parity), steps, peak, ÷2 / ×3+1 counts, trail, Step / Run / Clear / Preset
  buttons. **P** cycles presets 27, 7, 97, 255 and 703 (703 hits the overflow refusal)
- Title card (Start / Enter / Space, Back to Arcade) and HUD Back to Arcade. All buttons
  `FOCUS_NONE`. **Esc** → PauseOverlay

### Behaviour notes
- Enhanced buttons call Direct `step()` / `toggle_run()` / `clear()`; presets call Direct
  `set_value()` + `_restart_from_bits()`. Keys reach Direct's own `_unhandled_input` first.
- Juice only observes Direct: `value()`, `steps`, `history`, `running`, bit frames and the Info
  text (overflow). A step is labelled a halving when `next * 2 == prev` in Direct's history.
- Bit positions are read from the Direct sprites (`bit_pos()`), so overlays follow Direct.
- No Alchementrix IP. No `_enhanced` preview yet (gallery can use the Direct shot).

Tests: `tools/test_godotlab_collatz_enhanced.gd` (run by `tools/smoke_headless.sh`): real Area2D
clicks through the Enhanced stage, keys, presets, a 27 → 1 run and a 703 overflow compared
with a bare Direct twin, juice counters, launch / title / FOCUS_NONE and Esc.

### Todos
- Enhanced: the unfinished `adder.tscn` gate is still dropped; the carry ripple stands in for it.
