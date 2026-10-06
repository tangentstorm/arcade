# terratri: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/terratri |
| Source commit | `7c20663a2bd9d52da1ae25a2d43ac6a9e7479b6d` (2026-02-26) |
| Engine | TypeScript 5 rules (`src/shared/`), Vite web client, `ws` server |
| License | MIT for the implementation (© 2011-2026 Michal J Wallace). Game design by Adam "Atomic" Saltsman. |

## Direct edition (`direct/`): playable, hotseat 2P

Two players share one screen and take turns. There's no network: no WebSocket,
lobby, MCP, or tournament code.

| File | Role |
|---|---|
| `terratri_rules.gd` | Pure static port of `src/shared/terratri.ts`. Each TS export maps to a snake_case function: `boardToGrid`, `gridToBoard`, `startGrid`, `whoseTurn`, `findPawn`, `move`, `fortify`, `after`, `countFortsOnBoard`, `spentMoves`, `bankedMoves`, `fortSupply`, `isTurnOver`, `validSteps`, `winner`, `niceHistory`. It keeps the same string step and board notation, and grids are Arrays of 1-char Strings. |
| `terratri_game.gd` | Port of `Game.ts`: an immutable snapshot derived from the step string, plus `apply_step` (adds `\|` when the turn ends) and `at_step`. |
| `terratri_input.gd` | Pure functions that map a clicked cell or an abstract action (n/s/e/w/f/x/k) to a key in `valid_steps`. |
| `game.gd` / `game.tscn` | Thin Control shell. It turns input into `play_step()` calls and copies snapshot fields into labels. |
| `board.gd`, `fort_tray.gd`, `palette.gd` | Flat drawing. The board picks a whole-number cell size, and forts are drawn as blocky keeps. |

### Rule fidelity
- **Same algorithm, same notation.** History is the original step string
  (`nk|SWN|…`). All state (board, banks, supply, winner, legal steps) is
  recomputed from that string, as in the TS. Nothing else is stored.
- **`valid_steps` key order matches the TS object** (end, bank, n, s, e, w, f),
  because GDScript Dictionaries keep insertion order. The golden check compares
  this order as well as the contents.
- **TS quirks kept on purpose:**
  - Blue starts with 1 banked move.
  - Banking is only offered on the second action, and only when supply > 0.
  - Every non-pass step from index 2 onward spends one banked move.
  - End turn is hidden at index ≥ 2 if the board matches the turn start.
  - The anti-reversal rule only blocks a step that recreates the board from
    before the previous step.
  - Fortify needs 5 *unoccupied* claimed squares (`.`/`_` only).
  - `after()` replays without validating, so the test vector `nn|EF|fe|SF|`
    fortifies with too little territory, as it does in TS.
- **Possible dead end, kept from the original.** If a pawn has no legal step at
  the start of a turn (boxed in by edges and enemy pieces, and unable to fortify),
  `validSteps` is empty, and the TS game stalls there too. The Direct UI says so
  and offers Undo / Restart.

### Tests: `tools/test_terratri.gd` (110 checks)
- Every case from `terratri.test.ts` and `Game.test.ts`, mirrored one to one.
- Extras: `sq`/`sq_to_xy`, a 5-fort winner for each side, and the input mapping.
- **Golden playouts:** `tools/golden/terratri_playouts.json` records 8 seeded
  games played by the **original TS `Game` class** to a 5-fort win (6 Red, 2
  Blue, 467 states). Banking, bonus spending, and fortify are all exercised. For
  every state, the GDScript port has to accept the next step and reproduce the
  `steps`, `board`, `whoseTurn`, `winner`, both banks, both supplies, the ordered
  `validSteps`, and `history` exactly. Regenerate the file with
  `source/gen_golden.mjs`; the output is byte-identical.
- A UI replay of golden seed 1 through `game.tscn` checks the win banner,
  Restart, and Undo.

### Deliberate deviations (UI only, rules untouched)
- **Hotseat** replaces the two-browser link flow. The current side is shown
  with `>` and the status line.
- **Undo** (Backspace/U/Z) goes back one atomic step with `Game.at_step`. The
  online game had no undo, but in hotseat play it only fixes a misclick.
- **Input:** click a highlighted square (its step letter is drawn in the
  corner), or use arrows/WASD to move, F to fortify, Space/Enter/X to end the
  turn, K/B to bank, and R to restart. Esc opens the arcade PauseOverlay.
- **Look:** flat pixel-snapped squares in the original client's orange
  `#e08040` and blue `#4070c0`. It's not a copy of the web CSS. The fort tray
  shows forts on the board as solid squares, banked moves as inset squares, and
  supply as outlines.
- The history panel shows the last 12 `niceHistory` rows. The replay viewer
  (`replay.ts`) is not ported.

Scale mode: `expand`. The root is a reflowing Control, and the board picks a
whole-number cell size, so the pixels stay crisp at any window size.

`source/` holds reference copies of `src/shared/*.ts`, the two test files,
`rules.html`, `LICENSE`, and the golden generator. It has a `.gdignore`, so it
isn't imported or exported.

## Enhanced edition: planned (not started)
