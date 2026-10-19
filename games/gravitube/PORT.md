# gravitube — port notes

| | |
|---|---|
| Source | https://github.com/tangentscraps/gravitube ("just a godot scene"; Godot 3.x, `config_version=4`) |
| Author | tangentstorm, 2019-12-25 "attempt to model artificial gravity in godot" + 2020-01-06 "more geometry" |
| Pitch | Artificial gravity in a spinning space-station drum |
| Assets | None beyond the Godot `icon.png`; everything is CSG primitives + one cube mesh |
| Issue | #117 |

## Mechanics brief (original `Spatial.tscn` / `gravitube.tscn` / `Shell.tscn` / `gravitube.gd`)

- `Space` (main scene) holds two instances of `gravitube.tscn`: `port` at z=-50 with
  `speed = -12` and `starboard` at z=+50 with `speed = 12`.
- `gravitube.gd` is the only script: `_process` adds `speed * delta` to `rotation_degrees.x`,
  so the two drums spin about the world X axis at 12 deg/s in opposite directions.
- A drum (`gravitube.tscn`) is all CSG, axis along X:
  - `Shell.tscn`: CSGCylinder r=33, length 128, 32 sides, `use_collision`, minus an `Inner`
    r=32, length 132 subtraction, so a hollow 1-unit-thick tube open at both ends.
  - `hub` / `hub2`: r=1, length 132 axle cylinders (16 sides), one per direction; each ends in a
    `cap` (r=2, length 1) at x=-65 / x=+65 with a cross of two 64 x 1 x 2 boxes (the spokes,
    reaching the inner wall).
- `starboard/Cube`: a RigidBody (default physics material, 2-unit box shape, red
  `#f94646` cube mesh) inside the starboard drum near the floor, under default 9.8 gravity.
  Being a child of the spinning drum, the drum's rotation drags it around with the shell.
- `OmniLight` (default range) at the origin, a default `DirectionalLight` (pointing -Z).
- `Camera` (current, fov 94.9, far 500) inside the starboard drum near its floor at
  (-2.2, -28, 50.2), looking down the drum axis toward the `hub2` spokes, with a
  ProceduralSky environment. It is not parented to a drum, so the drum turns around it.
- No input, UI, gameplay or win/lose state. It is a sketch scene.

## Direct edition (`direct/`)

- `game.tscn` = `Spatial.tscn`, `gravitube.tscn` = `gravitube.tscn`, `shell.tscn` =
  `Shell.tscn`, `gravitube.gd` = `gravitube.gd`. Same node names, transforms, sizes, speeds,
  colors, lights and camera.
- No glue was needed: the source camera and lights already show the scene (the inside of the
  starboard drum, the far spoke cross turning against the sky, the red cube carried round).

### Differences from the original

- Godot 4.7 / GL Compatibility instead of Godot 3: node types renamed (`CSGCylinder3D`,
  `CSGBox3D`, `RigidBody3D`, `Camera3D`, ...), `ProceduralSky` -> `Sky` +
  `ProceduralSkyMaterial`, `SpatialMaterial` -> `StandardMaterial3D`.
- Godot 3 defaults written out explicitly because Godot 4 changed them (CSGCylinder radius
  1 / height 1, CSGBox 2 x 2 x 2, BoxShape extents 1, CubeMesh size 2).
- The unused `default_env.tres` (the camera has its own environment) and `icon.png` are not
  copied; the empty `_ready()` stub is dropped.
- The ProceduralSky and light defaults differ slightly between Godot 3 and 4, so colors and
  shading are close to, not identical to, the original.
- Esc goes to the arcade PauseOverlay (arcade convention). Gallery scale mode is `expand`
  (a 3D perspective view, no fixed stage).

### Enhanced

`"enhanced": "planned"` only.
