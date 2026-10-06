# Fnarbmlyx Binary Adder: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/fnarbmlyx, `demos/binary_adder/` |
| Source commit | `5b2654f0bd23de0df5211d1af38682637bcaa667` (master, 2023-08-21) |
| License | No LICENSE file in the source repo. It's Michal J. Wallace's (tangentstorm) own scratch repo, ported at his request. Its README is kept as `source/fnarbmlyx-README.md`. |
| Original | Godot 4.1 (`config_version=5`, converted from Godot 3), 1920×1080 window. A visual sketch, not a game |

## Direct edition (`direct/`): playable

An animated, ripple-carry 4-bit addition of `a = 3` and `b = 7`, shown as truth-table bit rows. A gold/yellow cursor (an `AnimationTree` state machine) sweeps column by column, filling in each result bit and carry, one step per second. The background breathes through a vertex shader, under a glow/colour-grade `WorldEnvironment`. It plays once and ends showing `1010` (carries `0111`).

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
- **Gold highlight tracks the active column.** The `init` animation no longer keys `carriage:position`. In Godot 4's AnimationMixer, leaving that track reset the carriage to `(0,0)`, so the teaching box floated in the corner instead of over the addend bits. Carriage origin is `(768, 280)` on the node (and re-applied in `adder.gd`); `move_carriage_left` still advances one 32px column. Cursor `border_color` is gold/yellow `Color(1, 0.85, 0)` (was orange).
- **`AnimationTree.deterministic = false`.** AnimationTree defaults to deterministic blending, which re-applies a zero/RESET value for any property a later clip does not key. After `add_2` faded `cursor:modulate` in, clips that only key position/size wiped modulate to black `(0,0,0,1)` while `border_color` stayed gold — so tests that only checked border color passed wrongly. Non-deterministic mode leaves unkeyed properties alone, so the gold highlight stays visible through the whole column walk.

`source/` holds the original files (plus the shared widgets they use) for reference. It has a `.gdignore`.

Tests: `tools/test_fnarb_demos.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A presentation makeover of the same ripple-carry sketch. **No rules are duplicated:**
`enhanced/game.gd` instances Direct `binary_addition.tscn` (shared `adder.gd` /
`rect.gd` / `truth_table.gd` / `shaded_grid.gd` + AnimationTree / gold carriage).
The scripted `['sync'|'set'|'travel', …]` walk, 1 s Timer cadence, a=3 / b=7 and the
plays-once quirk stay Direct. Enhanced only wraps the demo in 1280×720 letterbox
chrome and derives juice from result/carry bit colour deltas and carriage steps.
No Alchementrix IP.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | 1280×720 letterbox shell: field, HUD, title/done cards, juice |

### What changed (presentation only)
- **Stage:** fixed 1280×720 stage (`letterbox`). Direct's 1920×1080 demo runs in a
  SubViewport scaled into a 960×540 field (½) between thin side HUD panels.
- **Look / HUD:** circuit-glow backdrop, neon frame around the field, equation /
  column / live row readouts, controls strip. Direct gold/yellow carriage highlight
  is kept unchanged.
- **Juice:** bursts + floaters when a result or carry bit flips on; column banners;
  done flash/confetti when the result reads `1010`.
- **Title card** on boot (Space/Enter/Start); **Done card** after the walk; **R**
  reloads the Direct demo to watch again. Back to Arcade is `FOCUS_NONE`. Esc →
  PauseOverlay.

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Adder / bits / AnimationTree | `direct/binary_addition.tscn` scripts | same scene (instance), no copy |
| Stage | 1920×1080 SubViewport scaled to window | 1280×720 chrome around ½-scale Direct demo |
| Start | animation begins immediately | title card, then the same Direct boot |
| End | sits on final frame | done card + optional R replay |
| Esc / Back | PauseOverlay + help label | same + explicit Back (FOCUS_NONE) |

### Deferred
- Interactive a/b inputs or step-through controls (would be new mechanics)
- Dedicated `_enhanced` gallery preview (card can use the Direct shot)

Tests: `tools/test_fnarb_binary_adder_enhanced.gd` (run by `tools/smoke_headless.sh`).
