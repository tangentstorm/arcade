# LD48 ("deeper and deeper") — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/ld48 (project root `game/`) |
| Source commit | `34875e20def2f049c0b84a9c2e9dc03e0383bad4` (main, 2021-04-26) |
| License | MIT, © 2021 tangentstorm (`source/LICENSE`). Roboto Condensed: Apache 2.0 (`direct/fonts/LICENSE.txt`) |
| Original | Ludum Dare 48 entry; Godot 3.x (`config_version=4`), GDScript |

## Direct edition (`direct/`): playable, the whole jam game

The whole game is two rooms, and both are ported:

1. **`game.tscn`** (originally `scenes/previously.tscn` + `scenes/room0.gd`). It opens on the
   "Previously..." quake (camera shake). Then the Tetraminex chat sidebar
   plays the Teddy/Ernie dialog, Teddy stands up, and the teleporter drops into Ernie's
   hole. Stand next to it and hold **E** for 3 s (it sparkles) to warp.
2. **`ivan_office.tscn`** (originally `scenes/ivan's-office.tscn`). Ivan, walls, and the mine
   tiles. Hold the right mouse button to aim the teleporter beam (the cursor is green
   when the path is clear and red when blocked), then left-click to teleport. The original
   game ends here. Ivan has no dialog (`room-ivan.gd` was empty).

Controls are the same as the original: **A/D** or **←/→** walk, **Space** jumps (with coyote time),
**E** interacts, **9** toggles Dvorak (`,AOE` / `.`), and **0** fast-forwards the
dialog (the original's debug key).

### How it was migrated
- `godot --convert-3to4` was used as a reference only. Every scene and resource was
  rewritten by hand in format 3, with paths under `res://games/ld48/direct/`.
- **TileMaps → TileMapLayer.** The converter can't migrate 3.x atlas TileSets
  or `format = 1` tile_data (it produces a 16×16 TileSet with 0 cells). So
  `floor_tiles.tres` and `mine_tiles.tres` were rebuilt with one atlas source per Godot 3 tile id.
  The solid tiles got 128×128 collision squares. `tools/convert_tiles.py` re-encodes the cells
  into `tile_map_data` (360 + 108 + 718 cells, no flips), and `tools/build_scenes.py`
  regenerates both room scenes.
- **`room0.gd`:** the Godot 3 coroutine (`sleep(n); yield()` resumed by a 0.25 s
  Timer) is now `await wait(n)`, which awaits the next Timer step after the sleep runs out.
  The pacing is the same. `func helptext` (which clashed with the signal) is now `show_help`, and
  `func script` (which shadows `Object.script`) is now `run_script`.
- **`ernie.gd`:** `KinematicBody2D` → `CharacterBody2D`. `dxy = move_and_slide(dxy + G, UP)`
  → `velocity = dxy + G; move_and_slide(); dxy = velocity`. The movement constants are unchanged.
- **Shapes:** the Godot 3 scaled default shapes are baked into explicit sizes (capsule
  r 32.9 / h 105.9, reach circle r 80, teleporter circle r 30, Teddy/Ivan rects).
- **Gravity:** the original project used `default_gravity_vector = (0, 2.5)`, which is 2.5× gravity.
  The arcade project is shared, so each rigid body (teleporter, Teddy, Ivan) gets `gravity_scale = 2.5` instead.
- **Display:** the original ran 1920×1080 fullscreen. The intro camera's zoom 2 (Godot 3)
  becomes zoom ⅓ for the arcade's 1280×720 base, which shows the same 3840×2160 world area.
  The sidebar and help text stay parented to the camera, as in the original. Ivan's office had no
  camera, so a Camera2D at (960, 540) with zoom ⅔ frames the same 1920×1080.
- `Particles2D` → `GPUParticles2D` (`ParticleProcessMaterial`, with the random ranges converted
  to min/max). `AnimatedSprite` → `AnimatedSprite2D`.

### Deliberate deviations
- **Esc** opens the arcade PauseOverlay. The original reloaded the room on Esc, so **R** restarts the room now.
- **Teleporter aim** uses world mouse coordinates. The original used viewport coordinates, which only
  matched the world because Ivan's office had no camera.
- **Teleporter hang:** Godot 4 wakes a body that starts `sleeping = true` as soon as it enters the
  physics space, so the teleporter is frozen instead, until room0 releases it.
- **Teleporter fires once.** In Godot 3, the `teleport` signal re-emitted every frame after 3 s.
  Particle `amount` bottoms out at 1, because Godot 4 forbids 0.
- **Key 9** toggles Dvorak once per press. The original flipped every frame while 9 was held,
  and the mapping was inverted.
- The teleporter cursor is reset when Ernie leaves the tree, so it doesn't leak into the arcade.
- Dropped: the hidden `e00-screenshot` reference sprite, the `episode0/` editor tools
  (`CSVTileMap.gd`, `sprites.gd`, `epsiode00.tscn`), and the unused `blocks.png`/`sprites.png`.

### Remaining todos
- Physics feel was checked headless (land / walk / jump / interact / warp), but nobody has hand-played it
  side by side with the Godot 3 build yet. Godot 4's `CharacterBody2D` floor and wall rules
  differ slightly (for example, walking into the 1-tile step zeroes `dxy.x` every frame, as in the original).
- Rigid-body behavior (Teddy tipping, how the teleporter tumbles) comes from Godot 4 physics and may
  differ in detail from the Godot 3 run.
- Enhanced edition: not started.

Tests: `tools/test_ld48.gd` (run by `tools/smoke_headless.sh`).
