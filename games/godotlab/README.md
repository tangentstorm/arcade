# godotlab

Source: https://github.com/tangentstorm/godotlab (`master` @ `eca2b0b`, 2020-11-16, MIT, Godot 3).
It's a set of small Godot 3 experiments. Each playable one is its own gallery tile:

| Tile | Folder | Status |
|---|---|---|
| Collatz (GodotLab) | [`../godotlab_collatz/`](../godotlab_collatz/PORT.md) | Direct playable |
| GodotLab Game 00 | [`../godotlab_game00/`](../godotlab_game00/PORT.md) | Direct playable |
| GodotLab Game 01 | [`../godotlab_game01/`](../godotlab_game01/PORT.md) | Direct + Enhanced playable |
| GodotLab Tilemap | [`../godotlab_tilemap/`](../godotlab_tilemap/PORT.md) | Direct playable |

`source/` (`.gdignore`d) holds a verbatim copy of the four sub-projects' scripts, scenes,
and `project.godot` files, plus `LICENSE` (MIT, © 2018 tangentstorm). The Kenney asset pack,
`sprites/*.aseprite`, and game01's committed Godot 3 HTML5 export are left out. Every port
vendors only the assets it uses into its own `direct/assets/`.

Not ported: `sprites/` (aseprite characters, raptor, POMODORO). It's art only and has no scene.

Tests: `tools/test_godotlab.gd`, run by `tools/smoke_headless.sh`.
