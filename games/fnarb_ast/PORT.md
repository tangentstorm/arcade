# Fnarbmlyx Boolean Syntax Tree: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/fnarbmlyx, `demos/boolean_syntax_tree/` |
| Source commit | `5b2654f0bd23de0df5211d1af38682637bcaa667` (master, 2023-08-21) |
| License | No LICENSE file in the source repo. It's Michal J. Wallace's (tangentstorm) own scratch repo, ported at his request. Its README is kept as `source/fnarbmlyx-README.md`. |
| Original | Godot 4.1 (`config_version=5`, converted from Godot 3), 1920×1080 window. A visual sketch, not a game |

## Direct edition (`direct/`): playable

A random boolean expression tree (∧ ∨ ≠ over x₀–x₄, ⊥, ⊤), built from the fixed seed 82076 and laid out by a custom `Container`, on a shaded purple grid. No input. It's a static visual sketch for jprez-style presentations.

Files: `ASTNode.gd`/`.tscn`, `ASTNodeDemo.gd`/`.tscn`, `widgets/ShadedGrid.gd` → `ast_node*.gd/.tscn`, `shaded_grid.gd`. Apart from `res://` paths and the changes listed below, they're verbatim.

### Faithful quirks kept
- Godot's RNG (PCG32) is the same in 4.7, so seed 82076 builds the same tree as the original.
- The `ShadedGrid` shading isn't seeded, because the setter never runs for the default value. It's random each launch, as in the original.
- The original's 'non-equal opposite anchors' warning when the demo sets its own size is still printed.

### Deliberate deviations
- **Stage:** the demo runs unchanged in a 1920×1080 `SubViewport`, the original project's window size with stretch off. So `get_viewport()` sizes, anchors and mouse positions match the original. `direct/game.gd` scales that stage to fit the arcade window (2/3 at 1280×720) with linear filtering.
- **Help text:** a small controls hint sits in the margin, outside the stage. **Esc** opens the arcade PauseOverlay.
- **`@tool` and `class_name` dropped** throughout. Scripts are preloaded by path, so nothing leaks into the arcade's global class list and nothing runs in the editor.
- The per-draw debug `print('text:', text)` in `ASTNode._draw()` is removed.
- `NotoSansMono-Regular.ttf` is vendored subset to printable ASCII plus the operator glyphs used (OFL 1.1, `direct/assets/OFL.txt`).

`source/` holds the original files (plus the shared widgets they use) for reference. It has a `.gdignore`.

Tests: `tools/test_fnarb_demos.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A visual/UI makeover of the same sketch. **Nothing about the tree is rebuilt or copied:**
`enhanced/game.gd` preloads Direct `ast_node_demo.tscn` and instances it (shared
`ast_node_demo.gd` / `ast_node.gd` / `shaded_grid.gd`) in its native 1920×1080
`SubViewport`, so seed 82076, layout and glyphs stay Direct. Enhanced only frames
that viewport and draws overlays on top of it.

### Visuals / UI
- 1280×720 letterbox stage; Direct's 1920×1080 demo at ½ inside a 960×540 clipped
  field between side HUD panels and a thin title bar
- Deep indigo gradient + drifting motes around the Direct shaded purple grid
- **Grow-in:** on Start / **R** the field clip grows from the root downward, with a
  small pop at every node as its depth appears
- **Traversal wave:** once grown, a gold cursor walks the AST (breadth-first, pre-,
  in- or post-order; **Tab** / **T** cycles), leaving fading halos; a trail of the
  last visited op glyphs and a "done" flash when the walk completes, then it loops
- **Hover inspector:** mouse over a node to draw its gold path back to the root and
  show its op, L/R path, depth, child count and colour swatch
- Title card (Start / Enter / Space, op colour legend from Direct `ast_node` fills,
  Back to Arcade). HUD Back to Arcade. All buttons `FOCUS_NONE`. **Esc** → PauseOverlay

### Behaviour notes
- Overlay centres come from each Direct ASTNode's `global_position` + `link_point()`.
  The test compares the Enhanced tree (seed, count/height, every `op`) with a bare
  Direct twin.
- Traversals, hover and the grow-in are presentation only; Direct still has no input.
- Title `scale_mode` stays `letterbox`. No Alchementrix IP. No `_enhanced` preview yet
  (gallery can use the Direct shot).

Tests: `tools/test_fnarb_ast_enhanced.gd` (run by `tools/smoke_headless.sh`).
