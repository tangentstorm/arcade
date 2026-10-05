# Tentraminos — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/tentraminos |
| Source commit | `9be226632184a691a1ee68dab83ba1a5c12dedae` (master, 2013-08-25) |
| License | MIT, © 2013 michal j wallace (copy in `source/LICENSE`) |
| Original | Ludum Dare 27 entry; TypeScript + d3.js v3 drawing SVG |

## Direct edition (`direct/`) — playable

- `direct/tentraminos_logic.gd`: line-for-line GDScript port of `tentraminos.ts`:
  the `step()` state machine (NEWGAME / NEXTROUND / PLAYING / PAUSED / TIMEUP /
  CASCADE / CHECK4END / THEEND), the 100 ms tick, `runGravity` (cursor holds
  tiles in the air), flood-fill `findshapes`, `markshapes`, `clearshapes`
  (score 10·2^(n−4)), `release`, `refill`, `checkGameOver`, and the 18-color palette.
- `direct/game.gd` + `game.tscn`: redraws the original SVG layout (hold row,
  9×9 grid, 8px cursor frame with its 50 ms slide) at 2× scale, plus the clock/score text
  and the controls list from `tentraminos.html`.
- Same keymap as the original: arrows, WASD, Dvorak `c/h/t/n`; rotate with `z/x`, `k/l`, `o/u`; `p` pauses.
- As in the original, the board repaints only inside `step()`. So tiles you rotate
  while paused stay hidden until play resumes.

### Deliberate deviations
- **Restart:** the original said "refresh page to restart". Here, Enter, R, or Space restarts after game over.
- **`j` rotates too.** The help text says "o/j", but the code mapped keyCode 85, which is `u`. Both keys work.
- **Status line:** shows "paused" and "game over" text. The original had none.
- **Text:** the controls text is light gray rather than default black on #444, so it's readable. Godot's default font replaces Raleway 900.
- **Esc** opens the arcade PauseOverlay (pause, or Back to Arcade). Pausing the scene tree also stops the round clock.
- **Clock:** a fixed 100 ms step from an accumulator, capped at 1 s of catch-up, replaces `setInterval` with wall-clock dt.

### Not ported
- d3.v3.min.js (not needed) and the Google-Fonts CSS import.

`source/` holds the original `tentraminos.ts`, `.html`, `.css`, `README` and
`LICENSE` for reference. They're not part of the export.

Tests: `tools/test_tentraminos.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition — planned (not started)
