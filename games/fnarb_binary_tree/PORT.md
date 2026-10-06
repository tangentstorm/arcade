# Fnarbmlyx Binary Tree: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/fnarbmlyx, `demos/binary_tree/` |
| Source commit | `5b2654f0bd23de0df5211d1af38682637bcaa667` (master, 2023-08-21) |
| License | No LICENSE file in the source repo. It's Michal J. Wallace's (tangentstorm) own scratch repo, ported at his request. Its README is kept as `source/fnarbmlyx-README.md`. |
| Original | Godot 4.1 (`config_version=5`, converted from Godot 3), 1920×1080 window. A visual sketch, not a game |

## Direct edition (`direct/`): playable

A depth-5 complete binary tree of d3-category10-coloured disks, drawn with `_draw()` from the centre of the window down. No input.

Files: `BinaryTree.gd`/`.tscn` → `binary_tree.gd`/`.tscn`. Apart from `res://` paths and the changes listed below, they're verbatim.

### Faithful quirks kept
- The odd anchors/offsets (`anchor_right = 1.032`, …) are kept, so the tree sits slightly off-centre, as in the original.
- The background is the default clear colour (0.3 gray), as in the original project.

### Deliberate deviations
- **Stage:** the demo runs unchanged in a 1920×1080 `SubViewport`, the original project's window size with stretch off. So `get_viewport()` sizes, anchors and mouse positions match the original. `direct/game.gd` scales that stage to fit the arcade window (2/3 at 1280×720) with linear filtering.
- **Help text:** a small controls hint sits in the margin, outside the stage. **Esc** opens the arcade PauseOverlay.
- **`@tool` and `class_name` dropped** throughout. Scripts are preloaded by path, so nothing leaks into the arcade's global class list and nothing runs in the editor.
- `GsPalette.d3_category10` is inlined, since gslib/ isn't ported.

`source/` holds the original files (plus the shared widgets they use) for reference. It has a `.gdignore`.

Tests: `tools/test_fnarb_demos.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A visual/UI makeover of the same sketch. **Nothing is redrawn or copied:** `enhanced/game.gd`
preloads Direct `binary_tree.tscn` and instances it (shared `binary_tree.gd`, verbatim `_draw()`)
in its native 1920×1080 `SubViewport`, so `size`, anchors and the slight off-centre quirk are
the Direct ones. Enhanced only frames that viewport and draws overlays on top of it.

### Visuals / UI
- 1280×720 letterbox stage; the Direct viewport is framed around the tree (≈1.0×) inside a
  1200×420 clipped field, between a title bar and a bottom HUD row
- Deep-blue gradient + drifting motes. The SubViewport is transparent, so this chrome replaces
  Direct's default 0.3-gray clear colour behind the tree; faint per-level guides tagged `d0`…`d5`
  in each level's Direct colour
- **Grow-in:** on Start / **R** the field clip grows from the root downward, with a small pop
  at every node as its row appears
- **Traversal wave:** once grown, a gold cursor walks the tree (breadth-first, pre-, in- or
  post-order; **Tab** / **T** cycles), leaving fading halos; a trail of the last visited heap
  indices and a "done" flash when the walk completes, then it loops
- **Hover inspector:** mouse over a disk to draw its gold path back to the root and show its
  heap index, depth, L/R path, subtree size and colour swatch
- Title card (Start / Enter / Space, depth colour legend from Direct's palette, Back to
  Arcade). HUD Back to Arcade. All buttons `FOCUS_NONE`. **Esc** → PauseOverlay

### Behaviour notes
- Overlay positions come from `node_points()`, which reads the Direct node's own
  `node_radius`, `gap`, `DEPTH` and `size` (heap-indexed: `2i` = screen-left child). The test
  compares them with the Direct layout of a bare Direct twin.
- Traversals, hover and the grow-in are presentation only; Direct still has no input.
- Title `scale_mode` stays `letterbox`. No Alchementrix IP. No `_enhanced` preview yet
  (gallery can use the Direct shot).

Tests: `tools/test_fnarb_binary_tree_enhanced.gd` (run by `tools/smoke_headless.sh`).
