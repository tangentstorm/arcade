# dungeon-scroll-demo — port notes

| | |
|---|---|
| Source | https://github.com/tangentstream/dungeon-scroll-demo (Godot 4.3, Mobile renderer) |
| Author | tangentstream |
| Pitch | Randomly generate a GridMap from a template, as one section of an infinitely scrolling level |
| Assets | Kenney Mini Dungeon 1.5 (CC0), baked into `meshlib.tres` |
| Issue | #112 |

## Mechanics brief (original `RandomTiles.gd` / `RandomTiles.tscn`)

- `RandomTiles` (Node3D, `@tool`) holds two GridMaps on the same 21-item Kenney MeshLibrary,
  1x1x1 cells: `Template` at x=-4 and `Generated` at x=+4.
- Template is a hand-built corridor strip, 6 x 23 cells (140 cells incl. 2 on y=1):
  floor down the middle, wall/stairs edges, a few traps and characters.
- `rewrite_rules` is JSON: tile name -> list of `[probability, tile name]`. Default:
  `floor` -> 75% floor, 10% floor-detail, 10% rocks, 5% wall.
- `generate` (an inspector checkbox used as a button, editor only) re-parses the rules and
  copies every template cell into `Generated`, keeping the orientation; a cell whose item
  has a rule rolls one `randf()` and takes the first option whose running sum passes it.
  Cells without a rule copy unchanged.
- The scene ships with one baked Generated layout. There is no camera, light, input,
  scrolling or game loop: it is an editor demo (`_read()` is never called).

## Direct edition (`direct/`)

- `game.tscn`: the source's two GridMaps with their exact cell data, plus an orthographic
  Camera3D (60 degrees down, strips across the screen: Template on top, Generated below),
  a DirectionalLight3D and a dark WorldEnvironment so the scene is visible when run.
- `game.gd`: the source script, same rules and copy algorithm. `generate()` runs it at
  runtime; it takes an optional seed for the headless test.
- `meshlib.tres` + `assets/colormap.png`: the source MeshLibrary and Kenney colormap,
  texture path moved. `assets/License.txt` is Kenney's CC0 license.

### Differences from the original

- **Web: no GridMap.** The slim web engine has `module_gridmap_enabled=no`, so the GridMap
  scene failed to load on Pages. `direct/mesh_grid.gd` is a ~70-line stand-in with the API
  subset `game.gd` uses (`get_used_cells`, `get_cell_item[_orientation]`, `set_cell_item`,
  `clear`, `mesh_library`); it reads the same `data.cells` array and places one
  `MeshInstance3D` per cell exactly like GridMap (same 24 orthogonal bases). Layouts for a
  given seed and the desktop render are identical to the GridMap version.
- Godot 4.7 / GL Compatibility instead of 4.3 / Mobile; `@tool` and the inspector
  button are gone.
- **R** regenerates at runtime (the original only regenerates from the editor inspector).
- Added camera, light and environment (the original has none, so running it shows nothing).
- Uses its own `RandomNumberGenerator` (seedable) instead of global `randf()`.
- The FBX/OBJ/GLB source models and preview PNGs are not copied; the MeshLibrary already
  embeds every mesh it uses.
- Esc goes to the arcade PauseOverlay (arcade convention).
- Folder/registry id is `dungeon_scroll` (underscore, like every other arcade id).

### Enhanced

`"enhanced": "planned"` only.
