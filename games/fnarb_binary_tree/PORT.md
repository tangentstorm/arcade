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

## Enhanced edition: planned (not started)
