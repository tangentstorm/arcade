# godotlab_game01

Status: **Direct + Enhanced playable**. Source: godotlab/game01 (Godot 3). See [PORT.md](PORT.md).

Move the hero with WASD, which is `, A O E` on a Dvorak board, or with the arrow keys. Aim with the mouse
crosshair, and the hero always turns to face it. Esc opens the arcade pause.

- **Direct:** the original scene in the 1280×720 window (2× `Scene` root).
- **Enhanced:** playable. 1280×720 letterbox chrome around the same Direct `game.tscn` (shared
  `hero.gd` / `crosshair.gd`) in a SubViewport at ¾: checker floor, aim laser, crosshair rings,
  dust trail, fireball glow, off-field locator and telemetry. **R** resets the spawn.
