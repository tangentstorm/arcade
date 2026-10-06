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

### Todos
- Enhanced edition: not started.
