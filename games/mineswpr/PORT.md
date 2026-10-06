# mineswpr — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/gitweb/blob/main/mineswpr.org |
| Source commit | `ac9d365656ff8a1a0f0d54a9a1d60208b12db57c` (gitweb `main`, 2024-05-28; file dated 2013-02-03) |
| Engine | Retro Forth 11 on the Ngaro VM (`needs sets' vt' math'`) |
| License | No license in the source. It's tangentstorm's own work. |
| Tracking | GitHub issue #3 |

## Direct edition (`direct/`): playable

This is a **native GDScript rewrite**, not b4-gd. b4-gd can't run Retro, and it
has no terminal device yet. See inventory §2.2.

- `direct/mineswpr_logic.gd` ports the game words heading by heading:
  variables, grid-setup, point/cell/grid methods, `flood`, `«dead»`, `flag+`,
  `flag-`, `prod`, `hints-create`, `mine-add`, and `game-new`. Cells use the original
  bitset layout: `·mine ·cover ·flag` are bits 0–2, and the armed-neighbor count is
  stored at `$100` per neighbor. The board is `W=H=16` with `mineCount=24`.
- `direct/mswp_shell.gd` is the `chain: mswp'` parser plus just enough of the Retro
  listener to run it. It keeps a persistent data stack and reads numbers in **hex**
  (`mineswpr-play` does `reset hex`). The words are `+ - ?` (through `if-cell-ok`),
  `a`–`f` (push `$A`–`$F`), `r` (`game-new`), and `q` (`mineswpr-exit-hook`, which
  goes back to the arcade). It also supports the Retro words `play` and `reset`.
- `direct/mineswpr_screen.gd` ports `draw`, `show`, and `(x,y)` character for
  character. It keeps the same text, columns, and `vt'` colors: `|k..|w` are ANSI
  0–7 and `|K..|W` are 8–15, per `tangentlabs/forth/kvm.4th`. Brackets are striped
  `|c`/`|K` by row. Uncovered cells and mines hide their brackets with `|k`. The
  active cell gets `|m` for one draw. Flags are `|R !`, covers `|w -`, zero cells
  `|b -`, hints `|B n`, and mines `|r X` on game over.
- `direct/term_grid.gd` is a J-free TermGrid based on jprez's `JKVM.gd` (MIT).
  It has the same CHB/FGB/BGB buffers and the same xterm-256 palette. You write
  to it with `put(x, y, ch, fg, bg)` and `puts()` instead of pulling from J. It
  draws 80×25 cells of 15×26 px with the bundled Noto Sans Mono (subset to ASCII,
  OFL, see `direct/assets/OFL.txt`). It also emits cell click and hover signals.

### Original rules kept on purpose
- **Flood fill is cardinal-only.** `flood` spreads from zero cells through
  n/w/e/s only (`cardinal-neighbors-do`). So a hint cell that touches the empty
  region only diagonally stays covered. Classic Minesweeper would uncover it.
- **Flood ignores flags.** A flagged cell inside the flood area gets uncovered but
  keeps its `·flag` bit, so it still draws as `!`.
- **`?` on a flag removes the flag and then prods.** This is `prod` = `flag-` and then test.
  Left-clicking a flag does the same.
- **No first-click safety, no chording, no win check.** The original has none of these.
- **Commands still work after GAME OVER.** The parser never checks `gameOver?`.
  `r` restarts.
- **The stack persists between lines.** For example, `3` followed by `4 ?` prods (3,4). A
  command with fewer than two numbers does nothing. Out-of-range points are dropped.
  `10` is hex, so it's x=16 and out of range.

### Deliberate deviations
- **Mouse.** Each click runs the equivalent classic command, so the stack and
  `active-cell` behave exactly as if you typed it. Left click runs `x y ?`. Right
  click runs `x y +`, or `x y -` on a flagged cell. Hovering shows yellow `|Y`
  brackets. The original was keyboard-only.
- **Side panel** in columns 69–79. It shows mouse help, `flagCount` (the original
  tracked it but never showed it), the mine count, the last command, an
  "ALL CLEAR" note once every safe cell is uncovered (the game itself goes on as
  in the original), and the Esc hint.
- **Status line.** `.s` and the "game over. type r to restart" text get their own
  line (23) instead of following the dashed rule, so everything fits in 80×25.
  The stack prints as `<depth> n…` in hex. An unknown word shows `word ?` there
  instead of flashing before the redraw.
- **Esc** opens the arcade PauseOverlay (pause, or Back to Arcade). `q` goes
  straight back to the arcade, where the original dropped to the Retro shell
  `welcome` screen.
- **Recursion.** `flood` uses an explicit stack instead of recursion. It visits
  the same cells.
- The prompt has a blinking block cursor.

### Not ported
- The debug tools: `allHints?`, the `on-flood-step` flood debugger, `!!`/`??`, and the
  `flood-cursor` highlight hook. The highlight code path is in the renderer, but
  nothing sets it.
- The rest of the Retro shell: `words`, `welcome`, and any other Forth words.

`source/` holds `mineswpr.org` for reference. It isn't part of the export.

Tests: `tools/test_mineswpr.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A modern Minesweeper presentation of the same game. **No rules are duplicated:**
`enhanced/game.gd` preloads `direct/mineswpr_logic.gd` and `direct/mswp_shell.gd`
(plus the Direct Noto Sans Mono asset). Every move, whether it's a mouse click, the
keyboard cursor, or a typed line at the `ok` prompt, runs through the Direct `mswp'`
shell as the same `x y ?` / `x y +` / `x y -` command that Direct's own click handler
runs. That way the board changes exactly as it does in Direct. Enhanced compares the
grid before and after each command and uses the difference to drive the animations.
A rules fix in Direct therefore lands in both editions.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | 1280×720 letterbox stage: board view, HUD, `ok` console, result card, juice |

### What changed (presentation only)
- **Stage:** a fixed 1280×720 stage (`letterbox`, like Direct). It holds a 16×16 board of 38 px
  tiles with hex rulers (the numbers you'd type), a left panel (mines left, timer, best
  time, progress bar, New Game), and a right panel (controls, classic command cheat sheet,
  and a live `ok` prompt with the last command, `word ?` errors, and the `.s` stack).
- **Clearer cells:** beveled covered tiles, a dark checkered open floor, classic hint
  colors (1 blue, 2 green, 3 red, …), hover and press states, and a gold keyboard cursor.
  Direct's one-draw magenta active-cell highlight becomes a fading ping ring.
- **Flags:** pole-and-pennant flags that pop in with a back-out ease and a small spark burst.
  An unflag gives a puff. A flag that a flood uncovers stays visible, dimmed, the way Direct
  keeps drawing `!` there.
- **Reveal:** opened cells shrink away in a ripple ordered by distance from the prodded
  cell. Big floods show a `+N` floater.
- **Lose:** an explosion burst, screen shake, and a red flash. The hit mine sits on red, and the
  other mines cascade in by distance. Wrong flags get an X. A **BOOM!** card offers Play Again.
- **Win:** Enhanced checks for a win; the original has no win check, and Direct only shows
  "ALL CLEAR" in its side panel. Once every safe cell is uncovered, the timer stops, mines
  turn into green flags, confetti falls, the best time is saved to
  `user://mineswpr_enhanced.cfg`, and an **ALL CLEAR!** card appears.
- **Controls:** left click reveals and right click flags or unflags (the same as Direct). Touch
  reveals. Arrows move the cursor, Enter on an empty prompt reveals at the cursor
  (Shift+Enter or Tab flags), and F2 starts a new game. Typed commands work as in Direct, with
  hex numbers, the persistent stack, `r`, and `q`. Esc opens the arcade PauseOverlay, which
  also freezes the timer. Back to Arcade is top-left and never takes focus.

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Rules | `mineswpr_logic.gd` + `mswp_shell.gd` | same scripts (preload), no copy. `tools/test_mineswpr_enhanced.gd` checks the grid against Direct after every move |
| Flood | cardinal-only, ignores flags | same (the Enhanced view just animates it) |
| First click / chording | none | none (unchanged on purpose) |
| Win | no check ("ALL CLEAR" note in the side panel) | ALL CLEAR card, timer stop, best time (presentation only, so logic is untouched) |
| After GAME OVER | commands still run | typed commands still run (shell untouched). Board clicks and cursor keys pause behind the BOOM card until a new game |
| Look | 80×25 `vt'` terminal | tiles, flags, mines, HUD, juice on a 1280×720 stage |
| Timer / mine counter | not shown (flag count in the side panel) | mines left = 24 − flags, timer from the first reveal |

### Deferred
- No sound effects or music (Direct has none either).
- No dedicated `_enhanced` gallery preview in this PR, so the card uses the Direct shot.
- No difficulty sizes: the board stays 16×16 with 24 mines, as in the original.

Tests: `tools/test_mineswpr_enhanced.gd` (run by `tools/smoke_headless.sh`). It covers the
Direct script ownership, grid/flag parity with Direct over a scripted click session, typed
commands with the persistent stack, and loss parity with the BOOM card, juice, and frozen board.
It also covers the registry entry, launch and letterbox, Back to Arcade with FOCUS_NONE, keyboard
cursor/Tab/Enter, the typed flood with ripple, win with the ALL CLEAR card, best time, and
confetti, New Game resetting the view, and Esc → PauseOverlay (timer frozen) → Back to Arcade.
