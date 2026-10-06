# Fnarbmlyx Binary Space: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/fnarbmlyx, `demos/binary_space/` |
| Source commit | `5b2654f0bd23de0df5211d1af38682637bcaa667` (master, 2023-08-21) |
| License | No LICENSE file in the source repo. It's Michal J. Wallace's (tangentstorm) own scratch repo, ported at his request. Its README is kept as `source/fnarbmlyx-README.md`. |
| Original | Godot 4.1 (`config_version=5`, converted from Godot 3), 1920×1080 window. A visual sketch, not a game |

## Direct edition (`direct/`): playable

The 32 rows of truth tables for every 5-input conjunction of x₀–x₄ (rows for non-power-of-two combinations faded to 25%), as a 1024×1024 grid on a shaded blue background, which forms a Sierpinski-like pattern. No input.

Files: `BinarySpace.tscn`, `widgets/TruthTable.*`, `widgets/ShadedGrid.gd` → `binary_space.tscn`, `truth_table.*`, `shaded_grid.gd`. Apart from `res://` paths and the changes listed below, they're verbatim.

### Faithful quirks kept
- The hidden first `VBoxContainer` (x0–x4, O, I, ¬x rows) stays hidden, as in the original.
- The `Camera2D` at (960, 540) is kept. Inside the 1920×1080 stage it's the identity view, as it was originally.

### Deliberate deviations
- **Stage:** the demo runs unchanged in a 1920×1080 `SubViewport`, the original project's window size with stretch off. So `get_viewport()` sizes, anchors and mouse positions match the original. `direct/game.gd` scales that stage to fit the arcade window (2/3 at 1280×720) with linear filtering.
- **Help text:** a small controls hint sits in the margin, outside the stage. **Esc** opens the arcade PauseOverlay.
- **`@tool` and `class_name` dropped** throughout. Scripts are preloaded by path, so nothing leaks into the arcade's global class list and nothing runs in the editor.

`source/` holds the original files (plus the shared widgets they use) for reference. It has a `.gdignore`.

Tests: `tools/test_fnarb_demos.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A presentation makeover of the same 5-input truth-table space. **No rules are duplicated:**
`enhanced/game.gd` instances Direct `binary_space.tscn` (shared `truth_table.gd` /
`shaded_grid.gd`). The 32×32 conjunction grid, 25% fade on non-power-of-two rows, hidden
first VBoxContainer and Camera2D at (960, 540) stay Direct. Enhanced only wraps the demo
in 1280×720 letterbox chrome and derives juice from watching Direct row bits / modulate.
No Alchementrix IP.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | 1280×720 letterbox shell: field, HUD, title card, scan juice |

### What changed (presentation only)
- **Stage:** fixed 1280×720 stage (`letterbox`). Direct's 1920×1080 demo runs in a
  SubViewport scaled into a 960×540 field (½) between thin side HUD panels.
- **Look / HUD:** deep-space gradient + twinkles, neon frame around the field, scan-row /
  bits / lit-vs-faded readouts, pattern explainer, controls strip.
- **Juice:** row-scan highlight with bursts/floaters on lit rows; banner after a full
  pass ("SIERPINSKI PATTERN"); soft flash on Start.
- **Title card** on boot (Space/Enter/Start); **R** reloads the Direct demo to watch
  the scan again. Back to Arcade is `FOCUS_NONE`. Esc → PauseOverlay.

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Truth tables / shaded grid | `direct/binary_space.tscn` scripts | same scene (instance), no copy |
| Stage | 1920×1080 SubViewport scaled to window | 1280×720 chrome around ½-scale Direct demo |
| Start | demo visible immediately | title card, then the same Direct demo |
| Interaction | none | presentation scan / R replay only |
| Esc / Back | PauseOverlay + help label | same + explicit Back (FOCUS_NONE) |

### Deferred
- Interactive bit toggles or nvars slider (would be new mechanics)
- Dedicated `_enhanced` gallery preview (card can use the Direct shot)

Tests: `tools/test_fnarb_binary_space_enhanced.gd` (run by `tools/smoke_headless.sh`).
