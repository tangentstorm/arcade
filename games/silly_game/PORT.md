# Silly Game — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/silly-game (archived) |
| Source commit | `138de7f92a92b8e00bd12fe6f281b46a832d3079` (`reset scene on R, quit on escape`) |
| Original | Godot 3 (`config_version=4`, GLES2, 1366×768 fullscreen), `MainScene.tscn` + hero/aim/bullet/bullets/badguy scripts |
| License | No license file in the archived repo; arcade tree is MIT. Art (`aardvark.png`, `sprites.svg`, `tiles.svg`) from the same repo |

`source/` holds the original Godot 3 tree (`.gdignore`d). Playable assets are vendored under `direct/assets/`.

## Direct edition (`direct/`) — playable

| Original | Port |
|---|---|
| `MainScene.tscn` root `Node2D` with TileMap, badguy, heart, bullets, hero+Camera2D, aim | `direct/game.tscn` with the same nodes / positions / frames |
| `world.tres` beach autotile + water on `tiles.svg` | `world.gd` builds a Godot 4 `TileSetAtlasSource` (64×64) and replays decoded `tile_data` (671 cells) |
| `hero.gd` (`Sprite`) | `direct/hero.gd` (`Sprite2D`). WASD walk, facing frames, click-to-shoot pool |
| `aim.gd` | `direct/aim.gd`. Hidden OS cursor follows the mouse |
| `bullet.gd` / `bullets.gd` | Same pool of 51 frame-stepped bullets |
| `badguy.gd` (`KinematicBody2D` child) | `CharacterBody2D` + `move_and_collide(Vector2.ZERO)`; frame 12 on hit |

### How it was migrated
- `Sprite` → `Sprite2D`; `KinematicBody2D` → `CharacterBody2D`.
- Godot 3 beach autotile region `Rect2(256,256,384,192)` → atlas origin `(4,4)` on a 64×64 grid over `tiles.svg`. Water `Rect2(512,320,64,64)` → atlas `(8,5)`.
- `tile_data` PoolIntArray triplets decoded in `tile_data.gd` (cell xy, tile id, autotile atlas).
- Camera2D `current = true` → `enabled = true`. Zoom `(0.5, 0.5)` kept.
- Physics layers: badguy body on layer 6 (value 32); bullets mask 32 — same as the original.

### Faithful quirks kept
- **Frame-based motion.** Walk speed 8 and bullet speed 16 are pixels per physics frame, not delta-scaled (same as the original's `_process` at ~60 fps).
- **Bullet pool.** Starts at child index 1; template bullet stays parked off-map; bullets never despawn or stop.
- **Badguy "hit".** Only changes to frame 12; no HP, knockback, or bullet cleanup.
- **No walk clamp.** The aardvark can leave the island and stroll over empty space.
- **R reloads** the scene (original behaviour).

### Deliberate deviations
- **Esc** opens the arcade PauseOverlay instead of `get_tree().quit()`.
- **Fixed tick:** movement / shooting / bullets run in `_physics_process` (60 Hz) so feel matches a 60 Hz original on any refresh rate.
- **Cursor hygiene:** OS cursor returns while paused and on exit (headless skips mouse-mode changes).
- **HUD** hint label.
- **Scale mode `expand`:** camera-followed open map (like ld48); filling the window fits better than letterboxing a fixed stage.

### Not ported
- `default_env.tres` / GLES2 flicker workarounds (3D env unused by this 2D scene).
- Source `.aseprite` / `.ai` masters (PNG/SVG exports are enough to play).

Tests: `tools/test_silly_game.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition — planned (not started)
