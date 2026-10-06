# tangentstorm/arcade — Auditable Playbook

**Status:** DRAFT plan only — repo not created yet.  
**Owner:** Michal Wallace (`tangentstorm`)  
**Target:** `https://github.com/tangentstorm/arcade` → GitHub Pages WIP  
**Engine:** Godot 4.7.x (match box editor `/workspace/tools/godot/Godot_v4.7.2-stable_linux.x86_64` unless decision log says otherwise)  
**Decision log:** [`DECISION_LOG.md`](./DECISION_LOG.md)  
**Architecture:** [`ARCHITECTURE.md`](./ARCHITECTURE.md)  
**Date:** 2026-10-05 (America/New_York)

---

## Standing policy (operator)

| Rule | Meaning |
|------|---------|
| Drafts OK | Write plans, scaffolds, CI configs freely |
| Don't notify others | No @-mentions, no cross-repo pings, no Slack/email blasts |
| Own-repo PRs/creates OK | Creating `tangentstorm/arcade` and PRs on Michal's projects needs no extra ask |
| No Cursor cloud agents | Work via local executors + `gh` CLI on the box |
| This pass | **Repo already created at tangentstorm/arcade; continue scaffolding; **do not** mass-clone source titles |

---

## 1. Definition of Done (falsifiable)

The playbook is **done for a phase** only when every checkbox for that phase is true and independently re-checkable. Global product DoD:

1. **Repo exists** at `tangentstorm/arcade` (public, MIT unless decision log overrides).
2. **Single arcade app** boots in browser at `https://tangentstorm.github.io/arcade/` (or `…/arcade/index.html`) with:
   - title / splash → game picker → play → pause → return-to-arcade (no hard browser refresh required).
3. **At least one title** ships both editions (`direct` + `enhanced`) selectable from the picker.
4. **CI green:** push to `main` (or designated WIP branch) produces a Pages artifact; workflow log shows Godot export exit 0 and artifact size bound (see §5).
5. **No git submodules** in the tree that Pages/CI must recurse; all game assets are **vendored copies** under `games/<slug>/…`.
6. **Size gate (initial):** KEY download (wasm+js+pck+html+worklets) **≤ 12 MB gzip** on a smoke export with shell + one stub game (official nothreads template + compression). Custom slim template is a later lever, not a blocker for first Pages publish.
7. **Audit trail:** every non-obvious choice has a row in `DECISION_LOG.md` with evidence path.

**Falsifiers (any one fails DoD):** white screen on Pages; picker lists a game that cannot load; `git submodule` required to build; CI exports desktop-only; wasm served but arcade shell never yields control back from a game.

---

## 2. Scope units

### 2.1 In scope (v1 arcade)

| Unit | Description |
|------|-------------|
| Arcade shell | Title menu, game picker, pause overlay, return-to-arcade |
| Edition pair | Per slug: `direct/` (faithful port) + `enhanced/` (unique makeover; **no** cross-game UI kit required) |
| Registration | Data-driven catalog so shell discovers editions without hardcoding scene paths in UI code |
| Web export | Minimal Web preset (nothreads, `gl_compatibility`), Pages deploy |
| CI | `gh-pages` / Actions WIP build on the box-proven Godot binary |
| First real ports | Prefer small / already-Godot or terminal-adjacent titles before Flash/AS3 monsters |

### 2.2 Title inventory (sources — clone on demand, not up front)

| Slug | Source | Notes |
|------|--------|-------|
| `tetraminex` | `tangentstorm/tetraminex` (ActionScript) | Series; pick one playable slice for direct |
| `spiders-v-aliens` | `tangentstorm/spiders-v-aliens` (AS3/Flixel 2.55, LD21); box archive `/workspace/src-inventory/spiders-v-aliens/` | Direct + Enhanced playable (full AlienShip level; Enhanced is a lit widescreen makeover over the same rules); see `games/spiders_v_aliens/PORT.md` |
| `tentraminos` | `tangentstorm/tentraminos` (TypeScript/d3, LD27) | Direct + Enhanced playable (Enhanced = clearer board, modern HUD and juice over the same rules); see `games/tentraminos/PORT.md` |
| `ld48` | `tangentstorm/ld48` (GDScript) | Direct + Enhanced playable (Enhanced = restyled chat/help + juice over the same Direct rooms); see `games/ld48/PORT.md` |
| `ok-defender` | `tangentstorm/ok-defender` (oK/iKe, LD49) | Direct + Enhanced playable (Enhanced = ship/terrain/HUD juice over the same rules); see `games/ok_defender/PORT.md` |
| `shep` | `tangentstorm/shep` (Haxe/Flash 9 + physaxe) | Direct + Enhanced playable (Enhanced = clearer fuse/ship UI + juice over the same physics); see `games/shep/PORT.md` |
| `silly-game` | `tangentstorm/silly-game` (Godot 3, archived) | Direct + Enhanced playable (Enhanced = animated ocean, trails, hit juice + minimap HUD over the same Direct scene); see `games/silly_game/PORT.md` |
| `pico-games` | `tangentstorm/pico-games` (Pico-8) | `giraffe`: Direct + Enhanced playable (Enhanced = savanna-dusk restyle + landing juice over the same rules); see `games/giraffe/PORT.md` |
| `terratri` | `tangentstorm/terratri` (TypeScript 5, 2026 rewrite of the 2011 Python/GAE game) | Direct + Enhanced playable, hotseat 2P (Enhanced = lit tabletop, hop/claim/fort juice + player cards over the same rules); see `games/terratri/PORT.md` |
| `silverware` | `tangentstorm/silverware` (Turbo Pascal) | `doth`: Direct + Enhanced playable (Enhanced = torchlit dungeon chrome + pickup juice over the same Direct world/tiles); see `games/doth/PORT.md` |
| `gamemaker-stuff` | `tangentstorm/gamemaker-stuff` (archived) | Multi-mini, one slug per project. `gm_defense`: Direct + Enhanced playable (Enhanced = deep-space room, ship/squid glow + off-room locator over the same rules); see `games/gm_defense/PORT.md` |
| `killem-all` | `tangentstorm/gamemaker-stuff` `killem-all.gmx` (GameMaker: Studio 1.x, archived) | Direct + Enhanced playable (Enhanced = neon arena, tracers, thrust flame, radar + flight HUD over the same rules; still no enemies, as in the source); see `games/killem_all/PORT.md` |
| `toroidal-zombie-herder` | `tangentstorm/gamemaker-stuff` `toroidal-zombie-herder.gmx` (GameMaker: Studio 1.x, archived) | `toroidal_zombie_herder`: Direct + Enhanced playable (Enhanced = crypt-stone maze, wrap doors + ghosts, trap/caught juice, torus minimap HUD over the same rules; still no win state, as in the source); see `games/toroidal_zombie_herder/PORT.md` |
| `fnarbmlyx` | `tangentstorm/fnarbmlyx` (GDScript, archived) | GSL/Godot lineage. `fnarb_overlap`: Direct + Enhanced playable (Enhanced = letterbox chrome + mouse/subject/overlap HUD + colour-change juice over the same Direct `overlap_demo.tscn`); see `games/fnarb_overlap/PORT.md`. `fnarb_ast`: Direct + Enhanced playable (Enhanced = letterbox chrome + grow-in / traversal-wave juice + hover inspector over the same Direct `ast_node_demo.tscn`); see `games/fnarb_ast/PORT.md`. `fnarb_binary_adder`: Direct + Enhanced playable (Enhanced = letterbox chrome + equation/column HUD + bit-flip juice over the same Direct Adder scene; gold highlight kept); see `games/fnarb_binary_adder/PORT.md`. `fnarb_binary_space`: Direct + Enhanced playable (Enhanced = letterbox chrome + scan/bits HUD + row-scan juice over the same Direct `binary_space.tscn`); see `games/fnarb_binary_space/PORT.md`. `fnarb_binary_tree`: Direct + Enhanced playable (Enhanced = letterbox chrome + grow-in / traversal-wave juice + hover inspector over the same Direct tree scene); see `games/fnarb_binary_tree/PORT.md` |
| `GameSketchLib` | `tangentstorm/GameSketchLib` (Processing) | Engine/lessons — port **demos**, not whole lib. `sketchbots`: Direct + Enhanced playable (Enhanced = framed 300×300 @2× field, bot glow/squash/dust, meet + off-canvas juice over Direct `sketchbots_logic.gd`); see `games/sketchbots/PORT.md`. `gamesketchlib_demo`: Direct + Enhanced playable (Enhanced = framed 300×300 @2× field, bullet glow/trails, hit/soak/miss juice + aim guide over Direct `gsl_demo_logic.gd`); see `games/gamesketchlib_demo/PORT.md`. `bullet_demo`: Direct + Enhanced playable (Enhanced = letterbox chrome + glow/trails/hit/fizzle juice over the same Direct `game.tscn`); see `games/bullet_demo/PORT.md`. `invader_sketch`: Direct + Enhanced playable (Enhanced = starfield/glow/juice over Direct `invader_logic.gd`); see `games/invader_sketch/PORT.md` |
| `godotlab` | `tangentstorm/godotlab` | Experiments — cherry-pick playable scenes. `godotlab_collatz`: Direct + Enhanced playable (Enhanced = self-fitted 1280×720 chrome, bit flip / shift / carry-ripple juice, step breakdown + trajectory chart over the same Direct `game.tscn`); see `games/godotlab_collatz/PORT.md`. `godotlab_game00`: Direct + Enhanced playable (Enhanced = letterbox chrome + trail/glow/wrap juice over the same Direct `icon.gd` scene); see `games/godotlab_game00/PORT.md`. `godotlab_game01`: Direct + Enhanced playable (Enhanced = 1280×720 letterbox chrome, aim laser, dust trail, fireball glow + off-field locator over the same Direct `game.tscn`, SubViewport `stretch=false` @0.75); see `games/godotlab_game01/PORT.md`. `godotlab_tilemap`: Direct + Enhanced playable (Enhanced = letterbox sky chrome, landing dust / jump trails, minimap + run stats and a G tile-grid view over the same Direct `game.tscn` at ¾); see `games/godotlab_tilemap/PORT.md` |
| `ofcp` | live `wss://ofcp.tangentcode.com/ws` (+ offline `shared/` rules) | Pineapple Open Face Chinese Poker. Direct + Enhanced playable (Enhanced = felt chrome + place/score/Fantasyland juice over the same Direct thin client; modes cash/normal · windfall · progressive); see `games/ofcp/PORT.md` |
| `cupid` | `tangentstorm/cupid` (ActionScript 3 / Flixel v1, archived) | Direct + Enhanced playable (Enhanced = storm-to-sunset city, clearer bubbles/HUD + match juice over the same rules); see `games/cupid/PORT.md` |
| `mineswpr` | Live: `https://tangentstorm.github.io/mineswpr.html` via **b4-gd + j-talks terminal** | Direct + Enhanced playable (Enhanced = modern tiles, flags + win/lose juice over the same rules); see `games/mineswpr/PORT.md` |
| `gd-chesscoach` | `tangentstorm/gd-chesscoach` (Godot 4.3) | `chesscoach`: Direct + Enhanced playable (Enhanced = walnut board chrome + move-list HUD over the same Direct scene); see `games/chesscoach/PORT.md` |
| `canyon-run` | original (2026 Godot 4; no upstream repo) | `canyon_run`: Direct + Enhanced playable (Enhanced = layered River Raid–style canyon chrome + clearer HUD + juice over the same Direct logic; Claude Design parity deferred); see `games/canyon_run/PORT.md` |

### 2.3 Explicitly out of v1

- Cross-game shared “pretty UI” skin (enhanced editions stay unique)
- Desktop installers / Steam / itch bundles (Web/Pages first)
- Custom overnight slim-wasm as a **blocker** (optional Phase E lever; see b4-godot-dig `SLIM-BUILD.md`)
- Notifying third parties; rewriting source histories of old repos
- Cursor cloud agent fan-out (unavailable — use local executors)

---

## 3. Rigor (pstack)

| Lever | Practice |
|-------|----------|
| **Levers > hand ports** | Invest in: edition `manifest.gd` schema, scene bootstrap template, asset-vendor script, CI export recipe. Do **not** N× rewrite pause/return wiring. |
| **Verify on real artifact** | Pass/fail = exported `index.html` served over HTTP (local `python3 -m http.server` **and** Pages URL), not editor F5 alone. |
| **Verifiable units** | Each phase ends with a command + observable (screenshot path, curl MIME check, catalog JSON dump, CI run URL). |
| **Riskiest unknown first** | Sequence below puts **Pages+Godot boot** and **shell↔edition contract** before mass ports. |
| **Evidence** | Logs, export dirs, and screenshots land under `evidence/<phase>-<YYYYMMDD>/` in-repo (or `/workspace/tangentgames-plan/evidence/` until repo exists). |

**Rigor levels**

| Level | When | Bar |
|-------|------|-----|
| R0 smoke | Every push affecting export | Export exit 0; `index.wasm` present; HTTP 200 + `application/wasm` |
| R1 shell | Phases A–B | Picker lists fixtures; load/unload returns to arcade |
| R2 game | Per edition | Play 30s path: start → interact → pause → return; no orphan InputMap |
| R3 size | Phase E / releases | KEY gzip ≤ gate; decision log if gate moves |

---

## 4. Phase list (A–E, riskiest-unknown-first)

### Phase A — Pages pipeline + empty arcade boots *(risk: Godot→Pages)*

**Unknown killed:** Can we publish a nothreads Godot 4 Web build to GitHub Pages that loads?

1. Create repo `tangentstorm/arcade` (when operator greenlights; **not this draft pass**).
2. Scaffold layout per `ARCHITECTURE.md` (shell scenes only; zero real games).
3. Add `export_presets.cfg` Web preset: `variant/thread_support=false`, relative assets, `gl_compatibility`.
4. Add Actions workflow: install/cache Godot 4.7.2 + export templates → `--export-release "Web"` → upload Pages artifact / `peaceiris`/`actions/deploy-pages`.
5. Smoke locally: export → `python3 -m http.server` → console shows Godot version + single-threaded.

**Exit (falsifiable):** Public or Actions-preview URL loads black/canvas without COOP/COEP; `GODOT_THREADS_ENABLED = false` in `index.js`; evidence dir has export listing + one screenshot.

---

### Phase B — Edition registration contract + stub pair *(risk: shell↔game lifecycle)*

**Unknown killed:** Can games register, launch, pause, and return without leaking state?

1. Implement `ArcadeCatalog` / `EditionManifest` (see ARCHITECTURE).
2. Add fixture `games/_fixture/{direct,enhanced}/` with tiny Control scenes (colored rect + label).
3. Wire picker from catalog; pause overlay (Esc); **Return to Arcade** frees game subtree and restores menu InputMap.
4. Headless or scripted check: load direct → return → load enhanced → return (log lines or `--proof` style print).

**Exit:** Fixture both editions appear in picker; double round-trip leaves no stray autoloads/nodes under `GameHost`; R1 evidence recorded.

---

### Phase C — First real direct port (prove the lever) *(risk: portability)*

**Unknown killed:** Does the registration + vendor pattern survive a non-stub game?

**Recommended first title (pick one; log decision):**

| Priority | Slug | Why |
|----------|------|-----|
| 1 | `ld48` | Already GDScript Godot |
| 2 | `mineswpr` | Known live artifact + b4-gd adjacency |
| 3 | `fnarbmlyx` / `godotlab` | Godot-native experiments |

1. Vendor **copies** of needed scenes/scripts/assets into `games/<slug>/direct/` (script: `tools/vendor_from.sh`).
2. Adapt entry scene to implement `EditionEntry` API (start/pause/resume/exit).
3. Export + Pages WIP; R2 play path.
4. Document port checklist in `games/<slug>/PORT.md` (source commit SHA, omissions).

**Exit:** One real `direct` edition playable on Pages through the shell; PORT.md + decision log row naming the source SHA.

---

### Phase D — Enhanced makeover + fan-out seams *(risk: scale)*

**Unknown killed:** Can a second edition and a second title reuse levers without shell edits?

1. Ship `enhanced/` for the Phase C title (unique look/feel; no shared theme requirement).
2. Freeze fan-out seams (ARCHITECTURE §5): manifest schema, `GameHost` API, vendor script, CI path filters.
3. Add second title `direct/` only (prefer next-easiest Godot-native or tiny JS/TS game).
4. Optional: issue/PR template “Add edition” listing manifest fields + R2 checklist.

**Exit:** Picker shows ≥2 slugs; ≥1 slug has both editions; adding the second title required **zero** shell scene edits beyond catalog data.

---

### Phase E — Strip / size levers + catalog fill *(risk: over-strip)*

**Unknown killed:** How small can KEY get without breaking arcade?

1. Enable Pages/CDN-friendly compression verification (GitHub Pages already gzips many types; confirm wasm/`Content-Encoding` with curl).
2. Optional custom web template: `disable_3d`, fallback text server, module allowlist — follow `/workspace/b4-godot-dig/SLIM-BUILD.md`; smoke full R1+R2 after every strip.
3. Continue ports in risk-ordered batches (see §6 fan-out); keep enhanced unique per game.
4. Raise or reaffirm size gate in decision log with measured evidence.

**Exit:** Documented KEY gzip size; at least N titles agreed in decision log (propose N=3 both-editions or 5 direct-only as interim); no submodule; CI still green.

---

## 5. Verification harness plan

| Layer | Command / check | Pass criteria |
|-------|-----------------|---------------|
| **Export** | `godot --headless --path . --export-release "Web" build/web/index.html` | exit 0; `build/web/index.wasm` and `.pck` exist |
| **MIME/static** | `python3 -m http.server` + `curl -sI localhost:…/index.wasm` | `200`, `Content-Type: application/wasm` (or octet-stream acceptable if documented) |
| **Thread policy** | `rg "GODOT_THREADS_ENABLED" build/web/index.js` | `false` |
| **Catalog** | Godot headless script dumping registered editions | Matches `games/**/manifest.tres` (or JSON) count |
| **Lifecycle** | Automated input or `--proof` prints | `LOAD ok` / `RETURN ok` for fixture + target game |
| **Size** | `python3 -c '…gzip…'` on KEY files | ≤ gate; numbers pasted into evidence + decision log |
| **Pages** | `curl -sI https://tangentstorm.github.io/arcade/` | 200; follow-up wasm request not 404 |
| **CI** | `gh run list --repo tangentstorm/arcade` | latest workflow success on tip commit |

**Evidence layout**

```
evidence/
  A-20261005/
    export-listing.txt
    smoke.png
    curl-wasm.txt
  B-…/
  …
```

Until the repo exists, park evidence under `/workspace/tangentgames-plan/evidence/`.

---

## 6. Fan-out seams (what parallel workers may touch)

Safe parallel units **after Phase B exit**:

| Seam | Owns | Must not touch |
|------|------|----------------|
| `games/<slug>/direct/**` | One title’s faithful port | `arcade/**`, other slugs, CI root |
| `games/<slug>/enhanced/**` | That title’s makeover | Shared shell theme assumptions |
| `games/<slug>/manifest.tres` | Catalog metadata for that slug | Global autoload names |
| `tools/vendor_from.sh` | Copy recipe (PRs OK) | Export preset semantics without decision log |
| `evidence/<slug>-*` | Proof for that port | Overwriting other phases’ evidence |

**Integration owner (serial):** `arcade/**`, `export_presets.cfg`, `.github/workflows/**`, autoloads, `GameHost` API.

**Worker recipe (local executor):** branch `game/<slug>-direct` → vendor → implement `EditionEntry` → R2 locally → PR → CI export. No cloud agents.

---

## 7. Decision log template path

- **Canonical file:** [`/workspace/tangentgames-plan/DECISION_LOG.md`](./DECISION_LOG.md)  
- **After repo creation:** copy/move to `docs/DECISION_LOG.md` in the repo and keep this plan dir as historical snapshot or delete once mirrored.
- **Columns:** `date | decision | alternatives | why | evidence path`
- **Rule:** Any change to export threading, renderer, slim-template flags, license, first-port title, or Pages URL base path **requires** a new row before merge.

---

## 8. Immediate next actions (when implementation starts)

1. Operator confirms Phase C first slug (`ld48` vs `mineswpr` vs other).
2. Create `tangentstorm/arcade` (MIT, empty README pointing at Pages WIP).
3. Execute Phase A on the box with Godot 4.7.2; record evidence.
4. Do **not** clone the full title list until each port PR needs it.


## Scope correction

- **flappy_clone**: source in `tangentstorm/unitylabs` — port existing; do not invent.
