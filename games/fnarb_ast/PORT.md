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

## Enhanced edition: planned (not started)
