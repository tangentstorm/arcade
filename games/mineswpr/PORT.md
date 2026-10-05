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

## Enhanced edition: planned (not started)
