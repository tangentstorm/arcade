# GodotLab tilemap: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/godotlab, `tilemap/` |
| Source commit | `eca2b0b7bb0e3896e664db6783f67a08b46a7fbc` (master, 2020-11-16, "dummy project with assets from kenney.nl") |
| Original | Godot 3 (`config_version=4`): `Node2D.tscn`, a single TileMap over `assets/Tiles/tiles_spritesheet.png` |
| License | Code: MIT (`../godotlab/source/LICENSE`). Art: Kenney "Platformer Deluxe", **CC0** (`direct/assets/LICENSE-kenney.txt`) |

Vendored art: only `tiles_spritesheet.png`, `p1_spritesheet.png` (+ `.txt` frame list), and the Kenney license.

## Direct edition (`direct/`): playable
| Original | Port |
|---|---|
| `TileMap` (`format = 1`, `cell_size` 72) with tile 2 "tiles_spritesheet.png 2" (an autotile, 72×72 grid over the whole sheet with no spacing) | `TileMapLayer` + `TileSetAtlasSource` (72×72 region, no separation) |
| `tile_data` PoolIntArray (218 cells) | `direct/tile_data.gd` keeps the array **verbatim**. `tilemap.gd` decodes the Godot 3 packing (`cell = y<<16 \| x`, `coord = ay<<16 \| ax`) at load time and calls `set_cell` |

Because the tile grid is 72 px over Kenney's 70-px tiles with 2-px gutters, each cell shows a thin seam.
That's how the original looked.

**170 of the 218 cells draw nothing.** They use autotile coord (12, 9), whose 72×72 region lies past the
914-px-wide sheet, so the area is fully transparent. Godot 4 won't let an atlas tile lie outside its texture, so
those cells are skipped (`skipped_blank`). The visible level is the 48 grass and dirt cells, the same as in Godot 3.

### Deliberate deviations
- **Player (new):** the source had no character. `player.gd` adds Kenney's p1 alien from the same CC0 pack
  as a `CharacterBody2D`, with the stand, jump, and 11-frame walk frames from `p1_spritesheet.txt`. Controls are
  ←/→ or A/D to walk, and Space, ↑, or W to jump. It respawns after falling off the level.
- **Collision (new):** the original tiles had no shapes. Each painted atlas tile gets a full 72×72 square on physics layer 0.
- **Camera:** the original had none (it showed the world from (0,0) in a 1024×600 window, which cut off the
  bottom rows). A fixed Camera2D at (684, 500) frames the whole level in the arcade's 1280×720 view.
- **HUD** hint and Kenney credit. **Esc** opens the arcade PauseOverlay.

### Todos
- Enhanced edition: not started. A real level, coins, and enemies all fit the same pack.
