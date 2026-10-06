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

## Enhanced edition — planned (not started)
