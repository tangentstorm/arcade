# Fnarbmlyx Binary Adder: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/fnarbmlyx, `demos/binary_adder/` |
| Source commit | `5b2654f0bd23de0df5211d1af38682637bcaa667` (master, 2023-08-21) |
| License | No LICENSE file in the source repo. It's Michal J. Wallace's (tangentstorm) own scratch repo, ported at his request. Its README is kept as `source/fnarbmlyx-README.md`. |
| Original | Godot 4.1 (`config_version=5`, converted from Godot 3), 1920×1080 window. A visual sketch, not a game |

## Direct edition (`direct/`): playable

An animated, ripple-carry 4-bit addition of `a = 3` and `b = 7`, shown as truth-table bit rows. An orange cursor (an `AnimationTree` state machine) sweeps column by column, filling in each result bit and carry, one step per second. The background breathes through a vertex shader, under a glow/colour-grade `WorldEnvironment`. It plays once and ends showing `1010` (carries `0111`).

Files: `Adder.gd`, `Rect.gd`, `BinaryAddition.tscn`, `widgets/TruthTable.*`, `widgets/ShadedGrid.gd` → `adder.gd`, `rect.gd`, `binary_addition.tscn`, `truth_table.*`, `shaded_grid.gd`. Apart from `res://` paths and the changes listed below, they're verbatim.

### Faithful quirks kept
- Driven by the original script of `['sync' | 'set' | 'travel', …]` steps, each awaited on the 1 s `Timer`.
- It plays once. There's no replay, as in the original.

### Deliberate deviations
- **Stage:** the demo runs unchanged in a 1920×1080 `SubViewport`, the original project's window size with stretch off. So `get_viewport()` sizes, anchors and mouse positions match the original. `direct/game.gd` scales that stage to fit the arcade window (2/3 at 1280×720) with linear filtering.
- **Help text:** a small controls hint sits in the margin, outside the stage. **Esc** opens the arcade PauseOverlay.
- **`@tool` and `class_name` dropped** throughout. Scripts are preloaded by path, so nothing leaks into the arcade's global class list and nothing runs in the editor.
- **The Godot 4 migration bug is fixed.** `await _await[0].await[1]` (a bad conversion of Godot 3's `yield(obj, signal)`) is now `await Signal(_await[0], _await[1])`. In the 4.1 original it raised a script error on the first step, and the animation never ran.
- **`Camera2D` dropped.** In Godot 3 it was inactive (`current` defaulted to false). After the 4.x migration it became current, and with Godot 4's inverted `zoom` (0.2 = zoomed *out* 5×) it shrank the adder to a speck. The port shows the 1920×1080 view the Godot 3 scene had. Its `WorldEnvironment` child moved up to the scene root, inside the stage's own 3D world.
- **The empty `Tween` node is dropped.** It was unused, and Godot 4 can't instantiate `Tween` as a node.
- The debug `print`s are removed. The unused Godot 3 `.tres` animations stay in `source/` only.
- In the Compatibility renderer, 2D glow/adjustments from the `WorldEnvironment` may render more weakly than in the 4.1 Forward+ original.

`source/` holds the original files (plus the shared widgets they use) for reference. It has a `.gdignore`.

Tests: `tools/test_fnarb_demos.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition: planned (not started)
