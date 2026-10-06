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

## Enhanced edition (`enhanced/`): playable

A presentation layer over the **unchanged Direct rules**. `enhanced/game.gd` preloads
`direct/tentraminos_logic.gd` and calls the same `tick()` / `code()`. No rules are copied or edited.
The grid is still 9×9 with 10-second rounds and a 100 ms `step()`. The cursor still holds tiles in
the air, 4+ groups light up and score 10·2^(n−4) at TIMEUP, and the keymap is the same.
Enhanced code only reads the logic state and derives visuals from what changed between ticks.

| Surface | Direct | Enhanced |
|---|---|---|
| Board | Flat SVG squares at 2× (32 px cells), black strokes, 8 px black cursor frame | 60 px rounded tiles with bevel and drop shadow on a dark well. Each colour has a **glyph** (circle, triangle, diamond, square, plus, ring, X, bars; **G** toggles them) so colour isn't the only cue. Same-colour neighbours are joined by a band, so groups read as blobs. Lit groups glow and breathe |
| Danger | none | Top (game-over) row is tinted red. A tray slot shows a pulsing red **!** when rows 1–8 of its column are full, because the next drop would stick there unless a clear saves it |
| Tray | Hold row drawn like the grid | Inset "next drop" tray. Tiles bob, pop in on refill, and slide down into row 0 on release |
| Cursor | 50 ms slide | Glowing rounded frame with a 90 ms ease-out-back slide. Bumping an edge nudges it. Rotating flashes a ↺/↻ arrow and the four tiles **slide** to their new cells |
| Gravity | Tiles jump a row per 100 ms repaint | Per-cell offsets make falls continuous. Landing tiles squash and kick up dust |
| Clears | Tiles vanish at the next repaint | White flash per tile, particle burst in the group colour, `+N` popup per group, "N GROUPS!" popup for combos, screen shake scaled by size |
| HUD | `clock: 9` / `score: 40` text + controls list | Rounded side panel with a **clock ring**: a smooth countdown that turns orange→red and pulses in the last 3 s. The score counts up. **Best** score is saved to `user://tentraminos_enhanced.cfg`. Also round / tiles cleared / biggest group, a status line (last clear, paused), and a compact controls + rules card |
| Flow | Starts on load; "press Enter" status line at game over | Start card (Space/Enter or any move key starts the first round) and a Game Over card with stats + best. Enter/R/Space restarts, as in Direct |
| Pause (P) | Board stops repainting (rotations stay hidden) | Same rule. A veil hides the board and tray while P-paused, so rotations made while paused stay hidden too |
| Audio | none (the LD27 entry was silent) | Synthesized 16-bit SFX built at startup (move, rotate, land, drop, last-3-s ticks, clear ×3 tiers, pause, start, best, lose). **M** mutes. No audio assets are vendored |
| Esc / scale | PauseOverlay; `letterbox` | Same. Board + HUD fit 1124×646 inside the 1280×720 letterbox stage. A **< Back to Arcade** button on the side panel and on both cards uses `GameRegistry.return_to_arcade()`, with `focus_mode = none` so it never takes keys |

### Enhanced vs Direct: deliberate differences (presentation only)
- **Live board.** Enhanced draws the live `matrix` (not the `shown_*` snapshot), so rotations show
  immediately. Rules are identical: lit flags still update only inside `step()`, so a group made by a
  rotation lights up on the next 100 ms tick, as in Direct.
- **Start card.** The first round's clock doesn't start until the player starts. Direct starts on scene load.
- **Enhanced-only keys:** **M** (mute) and **G** (glyphs). Neither is in the original keymap, and neither touches the rules.

### Verification
`tools/test_tentraminos_enhanced.gd` (run by `tools/smoke_headless.sh`) drives the real scene. Keys
go through `_unhandled_key_input`. It replays every input on a bare Direct `tentraminos_logic.gd`
instance and asserts identical matrix / hold / score / clock / state / cursor:
- the first cascade
- every rotation key
- P pause/resume
- a TIMEUP clear (+20 for a group of 5)
- a scripted full game
- three random-input full games compared **every tick**

It also checks:
- registry entry: playable, letterbox
- start card and Back buttons
- juice: slide-in and fall offsets, rotate slides, burst/popup/shake, combo popup, decay to rest
- danger-column detection
- a paused tree freezes everything
- game over card, best score, restart

### Gaps / deferred (Enhanced)
- No mouse/touch play (keyboard only, like Direct).
- No music. The SFX are simple synth blips.
- No new modes (e.g. endless/zen or difficulty). The brief was polish over Direct rules.
