# Fnarbmlyx Overlap Demo: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/fnarbmlyx, `demos/overlap_demo/` |
| Source commit | `5b2654f0bd23de0df5211d1af38682637bcaa667` (master, 2023-08-21) |
| License | No LICENSE file in the source repo. It's Michal J. Wallace's (tangentstorm) own scratch repo, ported at his request. Its README is kept as `source/fnarbmlyx-README.md`. |
| Original | Godot 4.1 (`config_version=5`, converted from Godot 3), 1920×1080 window. A visual sketch, not a game |

## Direct edition (`direct/`): playable

GameSketchLib's OverlapDemo redone natively in Godot: nine 32×32 white `ColorRect`s on a slate background, with a live `mouseXY` readout in the corner. Hover a box (it turns cornflower blue), then press and drag it. While a button is held, overlapping boxes turn dim gray. The held box shows goldenrod, or black while it overlaps something.

Files: `OverlapDemo.gd`/`.tscn` → `overlap_demo.gd`/`.tscn`. Apart from `res://` paths and the changes listed below, they're verbatim.

### Faithful quirks kept
- Hover is driven by `mouse_entered`/`mouse_exited`, so a fast drag that outruns the box drops it.
- The half-matrix overlap loop (`if c1 == c0: break`) and the press colours (goldenrod / black) are unchanged, as are the stepping-stone comments.
- Boxes sit in the top-left corner of a 1920×1080 stage, as in the original. They look small in the gallery.

### Deliberate deviations
- **Stage:** the demo runs unchanged in a 1920×1080 `SubViewport`, the original project's window size with stretch off. So `get_viewport()` sizes, anchors and mouse positions match the original. `direct/game.gd` scales that stage to fit the arcade window (2/3 at 1280×720) with linear filtering.
- **Help text:** a small controls hint sits in the margin, outside the stage. **Esc** opens the arcade PauseOverlay.
- **`@tool` and `class_name` dropped** throughout. Scripts are preloaded by path, so nothing leaks into the arcade's global class list and nothing runs in the editor.

`source/` holds the original files (plus the shared widgets they use) for reference. It has a `.gdignore`.

Tests: `tools/test_fnarb_demos.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A presentation makeover of the same 9-box overlap sketch. **No rules are duplicated:**
`enhanced/game.gd` instances Direct `overlap_demo.tscn` (shared `overlap_demo.gd`). The
3×3 of 32×32 boxes, hover / press / drag, half-matrix O(n²) `colorize_overlaps`, and
goldenrod / black / dim-gray press colours stay Direct. Enhanced only wraps the demo
in 1280×720 letterbox chrome and derives juice from watching Direct box colours /
subject / mouseXY. No Alchementrix IP.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | 1280×720 letterbox shell: field, HUD, title card, overlap juice |

### What changed (presentation only)
- **Stage:** fixed 1280×720 stage (`letterbox`). Direct's 1920×1080 demo runs in a
  SubViewport scaled into a 960×540 field (½) between thin side HUD panels.
- **Look / HUD:** slate gradient + twinkles, neon frame around the field, live mouse /
  subject / overlap readouts, colour legend, controls strip.
- **Juice:** bursts/floaters when Direct box colours change (hover / grab / overlap);
  banner + soft flash on first overlap; soft flash on Start.
- **Title card** on boot (Space/Enter/Start); **R** reloads the Direct demo. Back to
  Arcade is `FOCUS_NONE`. Esc → PauseOverlay.

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Overlap / drag rules | `direct/overlap_demo.gd` | same scene (instance), no copy |
| Stage | 1920×1080 SubViewport scaled to window | 1280×720 chrome around ½-scale Direct demo |
| Start | demo visible immediately | title card, then the same Direct demo |
| Interaction | hover / drag (Direct) | same Direct interaction + presentation juice |
| Esc / Back | PauseOverlay + help label | same + explicit Back (FOCUS_NONE) |

### Deferred
- Zoomed crop on the box cluster (boxes stay small at ½ of 1920×1080, as in siblings)
- Dedicated `_enhanced` gallery preview (card can use the Direct shot)

Tests: `tools/test_fnarb_overlap_enhanced.gd` (run by `tools/smoke_headless.sh`).
