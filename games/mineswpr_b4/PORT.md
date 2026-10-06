# Mineswpr (b4) — port notes

| | |
|---|---|
| Source | [tangentstorm/b4-gd](https://github.com/tangentstorm/b4-gd) mineswpr TermGrid cart |
| Tracking | Arcade issue #45 Phase 4 |
| Standing | Additive gallery title; GDScript Mineswpr Direct/Enhanced stay playable |

## Direct edition (`direct/`): playable

Hosts the b4 carts inside the arcade shell:

| Path | Role |
|---|---|
| `direct/game.gd` + `game.tscn` | Arcade scene: Esc → PauseOverlay; `q` → `GameRegistry.return_to_arcade` |
| `direct/b4/B4VM.gd` | Vendored b4 VM (class_name `B4VM`) |
| `direct/b4/B4Asm.gd` | Cart assembler |
| `direct/b4/B4Term.gd` | `tm` (0xBE) terminal device |
| `direct/b4/B4Rand.gd` | `rn` (0xBD) random device |
| `direct/b4/MineswprCart.gd` | Boot + entry words (`keys` / `exec` / `blink` / …) |
| `direct/b4/carts/mineswpr-logic.b4` | Grid / flood / flag / prod / game-new |
| `direct/b4/carts/mineswpr-play.b4` | Draw + `mswp'` shell |

**Not vendored:** full b4-gd tree, `hello-term.b4`, duplicate Noto font.
TermGrid is the existing Mineswpr Direct script
(`res://games/mineswpr/direct/term_grid.gd`).

### Play

1. Gallery → **Original** → **Mineswpr (b4)**
2. Type hex commands at `ok` (`5 C ?`, `a b +`, `r`, `q`) or click
3. Esc opens PauseOverlay (Back to Arcade); `q` returns immediately; F2 new cart

Hover: the board cell under the mouse gets Y (11) brackets, like Mineswpr
Direct. `game.gd` paints this as a host overlay (same as b4-gd
`scenes/Mineswpr.gd`), because a full cart redraw costs ~90 ms. It saves the
bracket colors, lifts the overlay before each cart call, and puts it back after.

### Size

Vendored source ≈ 37 KB (scripts + two carts). No extra font (reuses Mineswpr
Direct Noto). Measured Web export KEY gzip delta vs same tree without
`games/mineswpr_b4/`: **+24 KB** (11.323 → 11.346 MB gz). Well under the
PLAYBOOK 12 MB KEY gzip gate.

### Tests

`tools/test_mineswpr_b4.gd` (picked up by `tools/smoke_headless.sh`): registry
entry, scene boot with fixed seed, typed prod, Esc does not quit the tree,
hover brackets 11 / survive a full draw / restore on leave.

Upstream screen/logic golden vectors live in b4-gd (`tools/test_mineswpr_*.gd`).
