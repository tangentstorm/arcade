# GodotLab game00: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/godotlab, `game00/` |
| Source commit | `eca2b0b7bb0e3896e664db6783f67a08b46a7fbc` (master, 2020-11-16) |
| Original | Godot 3 (`config_version=3`), `game00.tscn` + `icon.gd` |
| License | MIT (`../godotlab/source/LICENSE`). `assets/icon.png` is the Godot 3 project icon (Godot logo, CC BY 4.0, Andrea Calabró) |

## Direct edition (`direct/`): playable

| Original | Port |
|---|---|
| `game00.tscn` (Node2D → `icon` Sprite at (438, 246)) | `direct/game.tscn`. Same node, same position |
| `icon.gd` (`extends Sprite`) | `direct/icon.gd` (`extends Sprite2D`). Constants and logic unchanged |

The physics are the original's: each frame a held arrow adds `SPEED = 50` px/s to the velocity,
then the velocity is multiplied by `friction = 0.975`, and `position += delta * velocity`.

### Deliberate deviations
- **Fixed tick:** the per-frame impulse moved from `_process` to `_physics_process` (60 Hz). The feel
  then matches the original's 60 fps vsync on any refresh rate. On a 144 Hz monitor the original
  ran 2.4× faster.
- **Screen wrap:** the sprite wraps at the viewport edges, so it can't fly off forever.
  This is the `wrap` flag in `icon.gd`.
- **HUD hint label** with the controls. **Esc** opens the arcade PauseOverlay.

## Enhanced edition (`enhanced/`): playable

A visual/UI makeover of the same drift sprite. **Nothing is re-implemented:** `enhanced/game.gd`
preloads Direct `game.tscn` and instances it (shared `icon.gd`) in a native 1280×720
`SubViewport`, so SPEED, friction, wrap and arrow-key impulse are all Direct. Enhanced only
frames that viewport and draws overlays on top of it.

### Visuals / UI
- 1280×720 letterbox stage; the Direct viewport is framed at ¾ (`stretch=false` + `scale`,
  not `stretch=true`) inside a 960×540 clipped field, between a title bar and a bottom HUD row
- Deep-blue gradient + drifting motes. The SubViewport is transparent, so this chrome shows
  behind the Direct icon; a faint grid sits in the field frame
- **Motion trail** sampled from the Direct icon's positions; **speed glow** + velocity vector
  over the sprite; thrust sparks while an arrow is building speed
- **Wrap pops:** when Direct wraps at a SubViewport edge, Enhanced flashes, shakes lightly and
  floats a "WRAP" label
- Telemetry HUD: speed, position, distance, peak, wraps, boosts. **R** resets the Direct icon
  to its spawn without reloading the scene
- Title card (Start / Enter / Space, Back to Arcade) and HUD Back to Arcade. All buttons
  `FOCUS_NONE`. **Esc** → PauseOverlay

### Behaviour notes
- Direct `icon.gd` still reads `Input` actions itself; Enhanced does not copy SPEED / friction.
- Juice only observes Direct: `icon.position`, `icon.velocity`, and wrap jumps.
- Title `scale_mode` stays `letterbox`. No Alchementrix IP. No `_enhanced` preview yet
  (gallery can use the Direct shot).

Tests: `tools/test_godotlab_game00_enhanced.gd` (run by `tools/smoke_headless.sh`): parity vs a
bare Direct twin under the same arrow hold, trail / boost / wrap juice, launch / title /
FOCUS_NONE and Esc.

### Todos
- None for Enhanced; game01 / tilemap Enhanced still planned.
