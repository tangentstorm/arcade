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

## Enhanced edition (`enhanced/`): playable

A visual/UI makeover of the same level. **Nothing is re-implemented:** `enhanced/game.gd`
preloads Direct `game.tscn` and instances it as-is (shared `tilemap.gd`, `tile_data.gd`,
`player.gd`), so the tile replay (48 placed, 170 blank), the p1 alien's walk / jump / gravity,
the respawn and the fixed Camera2D are all Direct. Enhanced hides Direct's plain `Hud`
labels and draws around and on top of the level.

### Visuals / UI
- 1280×720 letterbox stage. Direct's native 1280×720 view sits in a SubViewport kept at
  1280×720 (`stretch = false`) and is scaled ¾ into a 960×540 clipped field, so Direct's
  camera framing is unchanged.
- The viewport is transparent, so Direct's grey clear becomes an Enhanced sky: gradient, sun,
  drifting clouds and two parallax hill bands that shift with the player. Dark "mortar" is drawn
  behind the painted cells, so the original 72-px grid seams read as grout.
- Juice (all observed from the Direct player): landing dust sized by fall speed plus a gold
  ripple on the landing cell, a jump puff + "jump" floater, walking dust, an afterimage trail
  while airborne, a ground shadow that shrinks with height, an off-view locator when the alien
  leaves the frame, and respawn sparks + flash + banner.
- HUD: player state (standing / walking / airborne ↑↓), position / velocity, current cell
  (on tile / over void), placed / blank counts, a minimap of the painted cells (blank cells
  faint) with the player, and run stats (jumps, landings, respawns, peak jump height in tiles,
  longest airtime, distance walked). Kenney credit kept.
- **G** toggles a tile-grid view: the 72-px grid, the painted cells, the current cell and the
  170 blank (12, 9) cells of the original `tile_data` outlined. **R** reloads a fresh Direct level.
- Title card (Start / Enter / Space, Back to Arcade) and HUD Back to Arcade. All buttons
  `FOCUS_NONE`. **Esc** → PauseOverlay.

### Behaviour notes
- Controls are Direct's own `Input` polling in `player.gd`; Enhanced consumes only Enter/Space
  on the title card and G / R in play.
- Juice only observes Direct: player `position`, `velocity`, `is_on_floor()`, `respawns`,
  the Sprite's region / flip (for the trail), and the TileMapLayer's cells. The blank-cell list
  is read from Direct `tile_data.gd`.
- World → stage mapping goes through the Direct viewport's `canvas_transform` (its Camera2D),
  then the ¾ field scale, so overlays follow Direct.
- No Alchementrix IP. No `_enhanced` preview yet (gallery can use the Direct shot).

Tests: `tools/test_godotlab_tilemap_enhanced.gd` (run by `tools/smoke_headless.sh`): no rules
copy, launch / title / FOCUS_NONE, SubViewport size / stretch / scale / layering, camera mapping,
and a bare Direct twin driven by the same held keys (rest, walk, jump arc, landing, respawn and
painted cells all match), juice counters, G grid, R reload and Esc.

### Todos
- Enhanced: no new level, coins, or enemies yet (all fit the same Kenney pack); the jump
  apex still leaves Direct's fixed camera frame (the off-view locator marks it).
