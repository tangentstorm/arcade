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

## Enhanced edition (`enhanced/`): playable, hotseat 2P

A visual/UI makeover of the same hotseat game. **No rules are duplicated:**
`enhanced/game.gd` preloads `direct/terratri_game.gd`, `direct/terratri_rules.gd` and
`direct/terratri_input.gd`, and takes the keymap from Direct `game.gd` (`KEYS`, loaded at runtime
because that script names the `GameRegistry` autoload). Every legal step goes through the same
`Game.apply_step()` with the same `valid_steps` check, and Undo uses `Game.at_step`, so a rules fix
in Direct lands in both editions. Enhanced only diffs the previous and next snapshots to decide
what to animate. No Alchementrix IP.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | 1280×720 stage shell: backdrop, header + territory bar, player cards, action bar, title / win / boxed-in cards, snapshot-diff juice |
| `enhanced/board.gd` | Tabletop board renderer + cell clicks (targets from `valid_steps` via `terratri_input.gd`) |
| `enhanced/sfx.gd` | Synthesized PCM blips (move, claim, capture, fort, bank, turn, undo, win); `M` mutes |

### What changed (presentation only)
- **Stage:** the title keeps `expand` (scale mode is per title), so the shell designs on a 1280×720
  stage and fits it to the window itself, while the night-gradient backdrop (diagonal weave,
  drifting motes, a soft glow in the colour of the side to move) fills the whole window.
- **Board:** a raised tabletop slab with a turn-coloured rim; rounded tiles with a top light;
  claimed land in deep orange / blue with a slowly breathing diamond weave; file/rank labels kept
  (a–e, 5–1, the original square names).
- **Pieces:** round tokens with a rim, highlight and ground shadow; the side to move bobs and gets
  a pulsing ring. Moves slide with a hop arc. A pawn on its fort sits on a plinth on top of the
  keep. Forts are two-tower castles with crenels, door and a waving pennant.
- **Hints:** legal squares get a pulsing outline, a chevron pointing away from the pawn and the
  step letter (as Direct). Hovering a target shows a ghost pawn; the fortify target shows a ghost
  castle over the pawn.
- **Juice (derived from snapshot diffs):** claim ripple + particles when a square changes hands;
  "CAPTURE" floater + shake when it was enemy land; forts rise with a squash, dust, gold sparks,
  shake and a "FORT n/5" floater; bank → "+1 BANKED" floater and a coin trail to the player card;
  a spent bank → "BONUS ACTION"; turn change → a sweeping "BLUE'S TURN · TURN n" banner; win →
  confetti and the win card. Illegal clicks/keys give a soft buzz + nudge instead of nothing.
- **HUD:** header status ("Red · action 2 of 2 · or bank it", bonus actions, boxed-in) and a
  red-vs-blue territory balance bar. Player cards: pawn badge, TO MOVE / WINNER chip, action pips
  (2 per turn, filled as used) plus banked bonus coins, a five-slot fort tray (castle = on board,
  coin = banked, outline = supply, same semantics as the Direct tray), forts / land / bank / supply,
  and a fortify readiness line ("★ FORTIFY READY [F]" or "Empty land n / 5"). The Red card keeps a
  colour-coded move log (last 8 `niceHistory` rows); the Blue card has a short how-to-play.
- **Cards:** title card (credits Adam Saltsman's design; Space / Enter / Start); win card with
  land + capture summary, Play again / Undo / Back to Arcade; a "BOXED IN" card for the
  original dead end with Undo / Restart.

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Rules / state | `terratri_rules.gd` + `terratri_game.gd` | same scripts (preload), no copy |
| Input | Direct `KEYS`, click targets, Bksp/U/Z undo, R restart | same map + `M` mute; title card first |
| Stage | reflowing Control, integer cell size | 1280×720 designed stage fitted to the window (`expand`) |
| Look | flat squares + blocky keeps | lit tabletop, tokens, castles, ghosts, animated claims/forts |
| Feedback | status label | banner, floaters, particles, shake, SFX |
| Counters | forts / bank / supply | + land, captures (view-only, from diffs), territory bar |
| Esc / Back | PauseOverlay | same + Back to Arcade (FOCUS_NONE) on the stage and cards |

### Deferred
- No AI opponent or online play (still hotseat); no replay viewer.
- No dedicated Enhanced gallery preview in this PR (card can use the Direct shot).

Tests: `tools/test_terratri_enhanced.gd` (run by `tools/smoke_headless.sh`): Direct script
ownership (no rules functions under `enhanced/`, keymap from Direct `KEYS`), all 8 golden TS
playouts (459 steps) replayed through Enhanced `play_step` with the snapshot (steps, board, turn,
winner, banks, supplies, ordered `valid_steps`, history) identical to a bare Direct twin at every
step, fort/capture juice counts, win card + confetti, Undo out of a win, claim/hop/bank/banner
juice and settling, the BOXED IN card (and Undo out of it), registry entry (`expand`), stage fit, title gating, Direct keymap, board
clicks, Backspace undo, K bank, Esc → PauseOverlay freezes the shell → Back to Arcade.
