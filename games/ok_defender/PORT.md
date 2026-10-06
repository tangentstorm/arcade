# oK Defender: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/ok-defender, `game.k` (199 lines) + `tasks.org` |
| Source commit | `68cd6eddc2cc57fa720629e0a48d353e704d5e96` (main, 2021-10-03) |
| License | **MIT** © Michal J. Wallace (copy in `source/LICENSE`) |
| Original | oK/iKe (John Earnest's K dialect in the browser), 320×200, `tick` at iKe's default 30 Hz (`frameDelay()` → `tr = 30`) |

## Direct edition (`direct/`): playable

- `direct/ok_defender_logic.gd` ports `game.k` verb for verb. One `step()` is one iKe `tick`
  at a fixed 30 Hz. Units are the original 320×200 pixels.
  - **Terrain:** `gndW` takes 20·fib tile widths (from 50 random picks) until the running sum
    passes 5 screens, and `worldW` is that exact sum. `gndH` is `_seaLevel+20*pn[0.1;0.1;rand]`.
    `pn` is ported from `ike/noise.js`: improved Perlin noise scaled to 0..1, with a permutation
    table reshuffled for every world, just as `512#<?256` was on every load. Each tile gets one of
    three solarized ground colours. The sky is six 30 px solarized bands.
  - **Humans:** one per tile, centred, standing on the ground.
  - **Ship:** moves 8 px/tick on both axes, wraps in x, and is clamped to y ∈ [18, 146]. It uses
    the thrust sprite only while moving in x (`stop[s]` otherwise) and is mirrored when facing left.
  - **Camera:** locked to the ship. `camXY` moves by the same `shSpd*dir`, so the ship always sits
    at screen x = 50.
  - **Aliens:** 5 at random x, y = 0. Stage 0: drift 1.3 px/tick toward `alTX` (nearest human
    + `tgtOfs`) and sink 1.95 px/tick down to `bad`. Stage 1: once at `bad` and within 1 px,
    engage the beam and take the human off the ground. Stage 2: carriers rise 1.3 px/tick.
  - **Phasers:** while Space is held, one fires **every tick** at `shXY + 22,18`. They move
    14 px/tick in the facing direction and live 16 ticks.
  - **Falling humans:** fall 1 px/tick. The single shared `falling` sprite turns 90° clockwise
    every 4 frames (`+|falling`), and its collision box turns with it.
  - **Collisions:** `overlap` is the original rectangle test. PHvAL kills the alien and the phaser,
    and a dying carrier drops its human at `(+12, +24)`. SHvFH lets the ship's 32×32 box catch
    falling humans.
- `direct/game.gd` draws the 320×200 screen scaled to fit, with nearest filtering. Draw order follows
  `draw`: sky, then `spriteLayer` (humans, falling, beams, aliens, ship, phasers), then the ground
  **on top of** the sprites, then the minimap. The minimap has a white box, black fill, and a
  solarized@2 camera box that splits in two when the seam is in view (`atSeam`). Sprites that
  straddle the seam are drawn on both sides, which is what `copyLeftSide` did.
- `direct/sprites/` holds the six original PNGs the code uses, salvaged unchanged. `phaserR` was
  never a PNG: it's the inline 4×1 sprite `,3 4 7 8` in the `arne` palette, drawn as 4 rects.

### Faithful quirks kept
- Auto-fire: one phaser per tick while Space is held, so 30 shots a second.
- Phasers always use `phaserR` and always spawn at ship + 22 px, even when flying left. They start
  on the ship's right side and pass back through it. (tasks.org: "set sprite direction of
  phasers": TODO.)
- No inertia. The camera is hard-locked to the ship, and there's no smooth follow (both TODOs).
- The ground is drawn over the sprites, so the tractor beam disappears into the hills.
- The held human isn't drawn under the alien. `beam.png` already has a human silhouette in it.
- The terrain and alien speeds are unchanged, so the opening wave of 5 aliens reaches the ground in
  about 2.4 s.

### Finishing the jam build (from `tasks.org`)
The jam build had no goal, no ending, and no way to lose. These come straight from the open TODOs
in `tasks.org`, using the simplest reading of each. Code for them is marked `[tasks.org]`.
- **[#A] Aliens show on the radar.** The minimap gets 1-px blips for humans (orange), aliens
  (green), and the ship (white). The DONE note "single pixels for aliens, humans, and hero" was
  never actually drawn.
- **[#A] More aliens spawn over time.** The first reinforcement comes at 8 s. The interval shrinks
  by 1/3 s per spawn down to 3 s, with at most 14 aliens. New aliens appear off-screen when possible.
- **[#A] Two aliens after the same person.** A new target prefers a human no one else is chasing.
  If an alien's target disappears, it retargets. The original kept homing and "abducted" a
  phantom human.
- **[#B] Carry and drop off.** A caught human is carried. Fly to the lowest altitude (y = 146) to set
  every carried human down on the ground under the ship. Each one counts as **saved**.
- **[#B] Ship vs alien = game over.** This uses the ship's opaque box (28×13 at 3,9), not the full
  32×32 cell.
- **[#B] Falling human vs ground = death.** The human becomes `human-ash.png` (an unused original
  sprite) for 3 s. *Choice:* a fall of 32 px (`beamRange`) or less is survivable, so shooting a
  carrier right at the beam doesn't automatically kill its human.
- **Abducted.** A carrier that rises off the top of the screen takes its human for good, which
  counts as **lost**.
- **[#B] Scoring / end game.** "Score is your time + #aliens killed − humans killed/abducted", plus
  #saved. The game ends when you crash or when no humans are left anywhere (ground, falling,
  carried, or beamed up). tasks.org: "a nihilistic game where you can never win but only prolong
  the inevitable."
- **[#C] Screen flow.** The title screen and game-over screen need a fresh Space press, so holding
  fire doesn't skip them. Pause is the arcade PauseOverlay (Esc).

### Deliberate deviations
- **One world, seam-aware.** The original doubled the terrain list for its seam copy
  (`gndW,:gndW`) but rolled new heights for the copy, and it spawned a second set of humans out
  there that aliens chased past `worldW` without wrapping. This port keeps one set of tiles and
  humans. Alien homing, alien x, and every overlap test wrap around the cylinder.
- **No crash bug.** The README's "crashes about half the time when aliens reach ground level"
  (oK issues #96/#97) doesn't apply.
- **Input:** arrows or WASD. Holding both directions cancels out. iKe used the last arrow pressed.
- **HUD:** time, kills, saved, lost, humans, and carrying are drawn at screen resolution in the top
  band, beside the minimap.
- **Esc** opens the arcade PauseOverlay, and pausing the tree freezes the simulation.

### Not ported
- The unused sprites `ship.png`, `alien0-tractor.png`, `empty-beam.png`, `phaser-r.png`, and
  `phaser-flash-r.png` (kept in `source/sprites/`). The explosion animation, the cities, and
  phasers vs beams or humans are all still TODO in tasks.org.
- The iKe GIF recorder (`fc`).

`source/` holds the original `game.k`, `tasks.org`, `README.md`, `LICENSE`, and all `sprites/` for
reference. It has a `.gdignore`, so Godot doesn't import it. The demo GIFs are in the upstream repo.

Tests: `tools/test_ok_defender.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A presentation makeover of the same Defender clone. **No rules are duplicated:**
`enhanced/game.gd` preloads `direct/ok_defender_logic.gd` and the Direct sprites under
`direct/sprites/`. Terrain generation, aliens, phasers, catch/drop-off, scoring, and
win/lose are the Direct simulation at the same fixed 30 Hz. Enhanced adds only read-only
presentation and juice, so a rules fix in Direct lands in both editions. No Alchementrix IP.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | 1280×720 letterbox shell: field view, side HUD, title/over cards, juice |

### What changed (presentation only)
- **Stage:** fixed 1280×720 stage (`letterbox`). The Direct 320×200 world draws at 3×
  (960×600) centered in the stage, with left/right chrome panels for stats and controls.
- **Terrain / sky:** Direct solarized sky bands plus a twinkling starfield; ground tiles keep
  Direct colours but get a lit ridge and darker footing so hills read at the larger scale.
- **Ship juice:** thrust trail and cyan exhaust sparks while moving in x; soft glow under the
  thrust sprite. Phaser shots keep Direct's four-colour bar and gain a bright tip streak.
- **Alien / human juice:** tractor-beam pulse glow; kill / catch / save / lost floaters and
  particle bursts driven from Direct score deltas (no rules branch). Crash: red flash, shake,
  and debris.
- **HUD / radar:** larger side counters (time, kills, saved, lost, humans, carry, score) and a
  wider minimap with the same seam-aware camera box and blips as Direct.
- **Screens:** restyled title and game-over cards. Space still starts / restarts through Direct
  (fresh press latch). Esc opens the arcade PauseOverlay (tree pause freezes the 30 Hz step).
  "Back to Arcade" is top-left and never takes keyboard focus.

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Rules / sim | `ok_defender_logic.gd` | same script (preload), no copy |
| Stage | 320×200 scaled to fit | 1280×720 chrome around a 3× (960×600) field |
| Look | nearest-filtered original sprites + HUD text | same sprites + trails, glows, floaters, side panels |
| Esc / Back | PauseOverlay | same + explicit Back to Arcade (FOCUS_NONE) |

### Deferred
- No new sprites or audio (Direct has none either beyond the salvaged PNGs).
- No dedicated Enhanced gallery preview in this PR (card can use the Direct shot).
- Phaser facing / inertia / smooth camera remain Direct TODOs from `tasks.org`.

Tests: `tools/test_ok_defender_enhanced.gd` (run by `tools/smoke_headless.sh`): registry entry,
scene launch + letterbox, Direct logic ownership, title → play via Space, juice on kill/catch,
Esc → PauseOverlay → Back to Arcade, and parity of a scripted session against a twin Direct world.
