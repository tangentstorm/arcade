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

## Enhanced edition (`enhanced/`): playable

A visual/UI makeover of the same sketch. **Nothing about movement or aiming is rebuilt or copied:**
`enhanced/game.gd` preloads Direct `game.tscn` and instances it (shared `hero.gd` / `crosshair.gd`
and the original art) in its native 1280×720 `SubViewport`, so the 10 px/frame walk, the
crosshair drift + clamp and the face-the-crosshair rotation stay Direct. Enhanced only frames
that viewport and draws overlays from the Direct sprites' positions / rotation.

### Visuals / UI
- 1280×720 letterbox stage. The Direct viewport is shown at ¾ (960×540 clipped field) with
  `SubViewportContainer.stretch = false` + `scale = 0.75`, not `stretch = true` (see Overlap #78)
- Transparent viewport over an Enhanced checker floor (32 Scene-px tiles), warm dusk chrome
- **Aim laser:** dashed red line from the hero's nose to the crosshair, plus pulsing rings and
  rotating ticks around the Direct crosshair
- **Walk juice:** gold dust trail and footstep puffs while the hero moves; sparks on snap turns
  (> 45° in one frame)
- **Fireball:** flicker glow + rising embers. It is still a static prop, as in Direct
- **Off-field locator:** Direct never clamps the hero, so when it walks off the screen an edge
  arrow (with distance) points at it and a banner suggests **R**
- Telemetry HUD: position, facing (degrees + compass), aim range, distance walked, snap turns,
  off-field count. **R** puts hero + crosshair back on their `game.tscn` spots
- Title card (Start / Enter / Space, Back to Arcade). HUD Back to Arcade. All buttons
  `FOCUS_NONE`. Direct's plain hint label is hidden. **Esc** → PauseOverlay
- The OS cursor is hidden over the field (the crosshair stands in for it) and shown over the
  chrome so the buttons stay usable; Direct `crosshair.gd` still restores it on pause / exit

### Behaviour notes
- The crosshair still reads `get_parent().get_local_mouse_position()` inside the SubViewport;
  with `stretch = false` and a 0.75 container scale that is the stage mouse mapped back into
  Direct window space, so mouse deltas move it exactly as in Direct.
- The test drives a bare Direct twin with the same **D** hold and compares hero / crosshair
  deltas, final position and rotation; it also checks the SubViewport mouse mapping.
- Title `scale_mode` stays `letterbox`. No Alchementrix IP. No `_enhanced` preview yet
  (gallery can use the Direct shot).

Tests: `tools/test_godotlab_game01_enhanced.gd` (run by `tools/smoke_headless.sh`).

### Todos
- Throwing the fireball at the crosshair is still the obvious next gameplay step (left out:
  Enhanced is presentation only).
