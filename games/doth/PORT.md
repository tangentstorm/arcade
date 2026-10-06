# Doth — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/silverware |
| Chosen root | `work/doth_a.pas` (47 428 B, ~1949 lines) |
| Issue | https://github.com/tangentstorm/arcade/issues/35 |

## Step 0 — version reconcile

| Path | Bytes (LF) | Archive date (by-date.org) | MANIFEST |
|---|---:|---|---|
| `work/doth_a.pas` | **47 428** | curated EDITED from newest | EDITED, nearest = `old/1996.08/DOTH-A.PAS` (82 line-diff) |
| `old/1996.08/DOTH-A.PAS` | 47 205 | **1996-03-29 21:20** | newest dated DOTH-A |
| `old/1995/DOTH-A.PAS` | 47 274 | 1995-04-16 | older |
| `old/1994/DOTH-A.PAS` | 47 139 | 1994-06-05 | oldest large engine |
| `work/doth.pas` | 3 705 | 1996-03-29 | small stub / menu shell |
| `work/doth_2.pas` | 8 665 | 1994-10-22 | earlier "Quest for an Empire" map walker |
| `other/dothscr.pas` | 21 601 | 1996-03-29 | CURRENT screen include |

**Decision:** start from **`work/doth_a.pas`**. It is the Doth-A lineage Michal asked for,
the largest engine (full object hierarchy: hero, walls, coins, gems, hearts, ammo, enemies,
stairs, rooms), and the curated tip of the newest archive snapshot (1996-03-29). The work/
copy differs from `old/1996.08/DOTH-A.PAS` only by revival whitespace/`^L` form-feeds (MANIFEST
EDITED, 82 lines) — not a stale merge miss. `doth.pas` / `doth_2.pas` are earlier or smaller
variants; `dmm.pas` is the unfinished map maker.

Supporting art/data used this PR:
- `other/dmap1.pic` — TheDraw 72×22 overworld (decoded → interior 70×20 walls/floor).
- HUD chrome inspired by `other/dplay1.pic` / `dplay1.cel` (Name/Rank/Gold/Magic/Health).
- Title brick field inspired by `other/dtitle.cel` colours (procedural pixels, not CEL blit).

No `.ROO` / `.WLD` world files survive in the archive (`gotoroom` expects `N.ROO`).

## Direct edition (`direct/`): playable core

| Piece | Role |
|---|---|
| `doth_world.gd` | 70×20 grid sim: move, walls, coin/gem/heart/ammo pickups, boulder push, score |
| `doth_levels.gd` | `OVERWORLD` from dmap1 decode; `STARTER` chamber documented against PAS constants |
| `doth_tiles.gd` | Procedural 16×16 colour atlas (SvA-like; not 1-bit; not pure text) |
| `game.gd` / `game.tscn` | Title + play, letterboxed 1120×368 stage, HUD, Esc → PauseOverlay |

### Controls
| Action | Keys |
|---|---|
| move | arrows / WASD / numpad (incl. diagonals) |
| starter room | `1` (title or in-play) |
| overworld | `2` / Enter / Space on title |
| pause / Back to Arcade | Esc |

### Faithful bits
- Room size `room[1..70,1..20]` from doth_a.
- Starting HP 30 / max 100 (`hpstart` / `hpstmax`).
- Pickup messages and rewards mirror coin/gem/heart/ammo `runinto` / handle msgs.
- Rank label "Apprentice" from `ranks[apprentice]`.
- Overworld silhouette from the real `dmap1.pic` continent.

### Deliberate deviations / MVP cuts
- **Pixel tiles instead of CP437 text mode** (Michal design direction for Direct).
- No enemy AI, shooting, spells, multi-room `.ROO` chain, save/load, editor, or music.
- Pickups on the overworld are placed for playability (archive has map terrain only).
- Boulder push is one-cell into empty floor (no full `walkinto` recursion).

## Enhanced edition (`enhanced/`): playable

A presentation makeover of the same Doth-A MVP. **No rules are duplicated:**
`enhanced/game.gd` preloads `direct/doth_world.gd` (and through it `doth_levels.gd`) plus the
Direct SvA-like procedural atlas from `direct/doth_tiles.gd`. Movement, walls, pickups, boulder
push, score and win are the Direct simulation. Enhanced only reads state after each `try_move()`
and derives presentation from the deltas, so a rules fix in Direct lands in both editions.
No Alchementrix IP.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | 1280×720 letterbox shell: torchlit field, bottom HUD, title/win cards, juice |

### What changed (presentation only)
- **Stage:** fixed 1280×720 stage (`letterbox`). The 70×20 map draws at the same 16 px tiles
  (1120×320) centered under a title bar, with a bottom stats panel and "Back to Arcade"
  (FOCUS_NONE).
- **Look:** same Direct SvA-like atlas; soft dungeon wash + ember motes behind the grid; wall
  drop shadows; pickup bob/pulse with coloured glow; hero squash on step / bump with a torch
  radius and ground shadow.
- **Juice:** particle bursts + floaters on coin/gem/heart/ammo; boulder-push sparkle; wall-bump
  shake; room-cleared flash + toast. View-only counters (coins/gems/hearts/ammo taken, pushes,
  bumps) derived from Direct deltas.
- **HUD:** gold / magic / health (bar) / ammo / moves / picks left / score / map id / message.
- **Title / win cards:** Enhanced boots on a title card with the sim idle; Enter/Space/2 →
  overworld, `1` → starter. Clearing the last pickup shows a win card; Enter/Space → title.
  Esc opens the arcade PauseOverlay.

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Rules / sim | `doth_world.gd` + `doth_levels.gd` | same scripts (preload), no copy |
| Tiles | procedural SvA-like 16×16 atlas | same atlas (preload), no copy |
| Stage | 1120×368 Control letterbox | 1280×720 chrome around 1120×320 field |
| Look | flat map + HUD strip | torchlit chrome, pickup pulse, collect juice |
| Start | title drawn in-room | title card overlay, then the same sim |
| Esc / Back | PauseOverlay | same + explicit Back to Arcade (FOCUS_NONE) |

### Deferred (still planned beyond this makeover)
- Enemy AI, shooting, spells, multi-room `.ROO` / `.WLD`, save/load, editor, music.
- Dedicated Enhanced gallery preview (card can use the Direct shot).

Tests: `tools/test_doth.gd` (Direct) and `tools/test_doth_enhanced.gd` (Enhanced; both run by
`tools/smoke_headless.sh`): Direct logic + tile ownership, move-by-move parity of starter/overworld
sessions (coin, wall bump, boulder push, 40 wander steps) against a bare Direct twin, collect /
win juice + counters, registry entry, launch + letterbox, title idles, `1` → starter, Esc →
PauseOverlay → Back to Arcade.
