# Doth — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/silverware |
| Chosen root | `work/doth_a.pas` (47 428 B, ~1949 lines) |
| Issue | https://github.com/tangentstorm/arcade/issues/35 |
| Visual SoT (Direct) | `games/doth/source/doth-reference-dosbox.png` (DOSBox 0.74 DOTH-A, 80×25 CP437) |

## Step 0 — version reconcile

| Path | Bytes (LF) | Archive date (by-date.org) | MANIFEST |
|---|---:|---|---|
| `work/doth_a.pas` | **47 428** | curated EDITED from newest | EDITED, nearest = `old/1996.08/DOTH-A.PAS` (82 line-diff) |
| `old/1996.08/DOTH-A.PAS` | 47 205 | **1996-03-29 21:20** | newest dated DOTH-A |
| `other/dothscr.pas` | 21 601 | 1996-03-29 | CURRENT screen include |
| `other/dplay1.pic` | — | 1996-03-29 | play chrome (controls / NaMe / CaSH…) |

**Decision:** engine from **`work/doth_a.pas`**. Direct *look* follows the DOSBox screenshot + `dplay1.pic` chrome (not the earlier SvA-like tile brief).

Supporting art/data:
- `other/dmap1.pic` — TheDraw 72×22 overworld → interior 70×20 walls/floor.
- `other/dplay1.pic` — controls column + status labels (odd capitalization).
- `games/doth/source/doth-reference-dosbox.png` — captured DOSBox reference.
- IBM VGA 8×16 glyphs: `arcade/assets/ibm_vga_8x16.png` (from `b4/ref/go/dosfont.py`).

No `.ROO` / `.WLD` world files survive (`gotoroom` expects `N.ROO`).

## Direction flip (2026-10)

Michal overturned the older “not pure text / SvA look” brief. **Direct is now an 80×25 CP437 text terminal** matching DOSBox DOTH-A:

- Black background, brown walls (`wallatr=$06` → ANSI brown / VGA `#AA5500`), yellow `☺` hero.
- Shared `games/_shared/term_grid.gd` (CHB/FGB/BGB, xterm-256) with IBM VGA atlas — also used by mineswpr / mineswpr_b4.
- `doth_tiles.gd` SvA 16×16 atlas **no longer drives Direct** (still preloaded by Enhanced until that edition is restyled onto TermGrid).

## Direct edition (`direct/`): playable core

| Piece | Role |
|---|---|
| `doth_world.gd` | 70×20 grid sim: move, walls, coin/gem/heart/ammo pickups, boulder push, score |
| `doth_levels.gd` | `OVERWORLD` from dmap1 decode; `STARTER` chamber |
| `game.gd` / `game.tscn` | One TermGrid 80×25 @2× (1280×800): map + dplay1 chrome + status |
| *(unused by Direct)* `doth_tiles.gd` | Legacy SvA atlas — Enhanced only |

### Controls
| Action | Keys |
|---|---|
| move | arrows / WASD / numpad (incl. diagonals) |
| starter room | `1` (title or in-play) |
| overworld | `2` / Enter / Space on title |
| pause / Back to Arcade | Esc |

### Faithful bits
- Room size `room[1..70,1..20]`; map drawn at screen (1,1)–(70,20) inside dplay1 frame.
- Wall glyph `█` / attr brown; hero `☺` / yellow `$0E`; heart `♥` `$0C`; ammo `¶`; boulder `O`.
- HUD labels from dplay1: `controls` / `NoRTH`… / `NaMe` `RaNK` `CaSH` `MaGiC` `aMMo` `HeaLTH`.
- Starting HP 30 (`hpstart`); rank "Apprentice".

### Deliberate deviations / MVP cuts
- Coins drawn as green `$` (screenshot) rather than PAS yellow `•` (`#7`).
- Gems as yellow `*` (levels / shot) rather than PAS blue `♦`.
- No enemy AI, shooting, spells, multi-room `.ROO` chain, save/load, editor, or music.
- Timer is session elapsed, not original clock object.

## Enhanced: still tile chrome

`enhanced/` remains the 1280×720 torchlit shell over Direct `doth_world.gd` + `doth_tiles.gd`. Planned: thin TermGrid restyle (color/chrome) once Direct parity settles — not blocking this PR.

Tests: `tools/test_doth.gd` (also run by `tools/smoke_headless.sh`).
