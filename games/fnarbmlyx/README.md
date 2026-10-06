# fnarbmlyx

Source: https://github.com/tangentstorm/fnarbmlyx (`master` @ `5b2654f`, 2023-08-21, Godot 4.1). It's tangentstorm's Godot
scratch repo: graph-drawing tools, algorithm animations, a terminal control, and J experiments.
There's no LICENSE file; it's Michal J. Wallace's own code. Each folder under `demos/` is its own
gallery tile:

| Tile | Folder | Source | Status |
|---|---|---|---|
| Fnarbmlyx Overlap Demo | [`../fnarb_overlap/`](../fnarb_overlap/PORT.md) | `demos/overlap_demo` | Direct playable |
| Fnarbmlyx Boolean Syntax Tree | [`../fnarb_ast/`](../fnarb_ast/PORT.md) | `demos/boolean_syntax_tree` | Direct playable |
| Fnarbmlyx Binary Tree | [`../fnarb_binary_tree/`](../fnarb_binary_tree/PORT.md) | `demos/binary_tree` | Direct playable |
| Fnarbmlyx Binary Adder | [`../fnarb_binary_adder/`](../fnarb_binary_adder/PORT.md) | `demos/binary_adder` | Direct playable |
| Fnarbmlyx Binary Space | [`../fnarb_binary_space/`](../fnarb_binary_space/PORT.md) | `demos/binary_space` | Direct playable |

Not ported: `gslib/` (GsApp, a node/edge sketching editor; it's a tool, not a demo), the `widgets/`
other than TruthTable/ShadedGrid, `addons/sketchlib`, and the J bridge experiments.

Tests: `tools/test_fnarb_demos.gd`.
