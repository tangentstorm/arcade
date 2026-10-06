# Chess Coach — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/gd-chesscoach |
| Source commit | `80baede29e80c485b963d920d9ea2519106d08bd` |
| Original | Godot 4.3 (`config_version=5`, Mobile renderer), 400×400, `board.tscn` + ChessBoard / Tray / Square / GameEditor |
| License | No LICENSE in the source repo; Michal J. Wallace (tangentstorm) own scratch; arcade tree is MIT |

`source/` holds the original tree (`.gdignore`d). Playable copy lives under `direct/`.

## Direct edition (`direct/`) — playable

| Original | Port |
|---|---|
| `board.tscn` root `Game` VBox + white/black trays + board + AnimationPlayer | `direct/game.tscn` same layout plus Toolbar (Back / Reset / Replay) |
| `ChessBoard.gd` (@tool Panel, FEN setup/clear via trays) | `chess_board.gd`: no `@tool`; wires trays; `_ready` stows mid-animation pieces then `setup_board(INIT_FEN)` |
| `Tray.gd` / `Square.gd` | `tray.gd` / `square.gd` (same grid / colours) |
| `GameEditor.gd` + `"fool's mate"` AnimationLibrary | Kept on an `Editor` child; Replay button plays it after Reset |
| `sprites/*.png` | Vendored under `direct/sprites/` |

### Deliberate deviations
- **Esc** opens the arcade PauseOverlay (original had no quit-on-Esc; `movie_quit_on_finish` disabled).
- **No autoplay** on launch — starts at `INIT_FEN` so the board is a clean starting position. Replay is opt-in.
- **Back to Arcade** / Reset / Replay toolbar.
- **Scale mode `letterbox`** for the ~400×400 board stage.
- `@tool` dropped so nothing runs in the arcade editor.

### Not ported
- Stockfish / engine coaching
- The separate Go `chesscoach` project
- Editor-only `go` / `clear` export toggles (call `setup_board` / `clear_board` from code / tests instead)

Tests: `tools/test_chesscoach.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A presentation makeover of the same FEN board. **No rules are duplicated:**
`enhanced/game.gd` instances `direct/game.tscn` (shared `chess_board.gd` / `tray.gd` /
`square.gd` / `game_editor.gd` + sprites + the recorded `"fool's mate"` AnimationPlayer).
FEN setup, clear, tray stow and replay stay Direct. Enhanced only wraps the scene in
1280×720 letterbox chrome and derives juice from AnimationPlayer / modulate deltas.
No Stockfish. No Alchementrix IP.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | 1280×720 letterbox shell: walnut board, FEN/move-list HUD, title card, juice |

### What changed (presentation only)
- **Stage:** fixed 1280×720 stage (`letterbox`). Direct's ~400×400 board runs in a
  SubViewport scaled into a 520×520 field with file/rank labels and a wood frame.
- **Look:** original blue squares restyled to walnut / cream (Direct `square.gd` kept;
  only `color` is overwritten). Direct toolbar hidden; Enhanced owns Back / Reset / Replay.
- **HUD:** FEN / status panel, piece + capture counters, recorded-game move list (from
  Direct Editor `json_moves`), replay progress bar.
- **Juice:** reset/replay bursts, capture fades detected from Direct modulate keyframes,
  checkmate flash when the AnimationPlayer finishes.
- **Title card:** Enhanced boots on a title; Enter/Space loads the Direct scene. Esc →
  PauseOverlay. Back to Arcade is FOCUS_NONE.

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Board / trays / replay | `direct/game.tscn` scripts | same scene (instance), no copy |
| Stage | ~400×400 Control letterbox | 1280×720 chrome around scaled Direct board |
| Look | blue squares + flat trays | walnut board, side HUD, move list |
| Start | board at INIT_FEN immediately | title card, then the same Direct boot |
| Esc / Back | PauseOverlay + toolbar Back | same + explicit Back (FOCUS_NONE) |

### Deferred
- Stockfish / engine coaching (still out of scope for both editions)
- Live FEN serializer / free piece dragging
- Dedicated `_enhanced` gallery preview (card can use the Direct shot)

Tests: `tools/test_chesscoach_enhanced.gd` (run by `tools/smoke_headless.sh`).
