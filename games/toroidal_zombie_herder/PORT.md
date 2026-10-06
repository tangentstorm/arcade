# Toroidal Zombie Herder — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/gamemaker-stuff (archived), `toroidal-zombie-herder.gmx/` |
| Source commit | `e5416cc625283cfec90286aa396f583377d83231` (master, 2017-04-19) |
| License | none stated (tangentstorm's own repo) |
| Original | GameMaker: Studio 1.x project: one room, six objects, one GML script, the rest drag-and-drop actions |

## Direct edition (`direct/`) — playable

- `direct/room0.gd` is **generated** from `source/rooms/room0.room.gmx` by
  `tools/room_to_gd.py`. It holds all 651 instances in creation order. That includes the
  stacked duplicates (stacked coins each score) and the one half-scale coin.
- `direct/tzh_world.gd` simulates the room at the original room speed (30 steps/s), with GM event order:
  1. **Mouse, global left button** (obj_hero): `action_potential_step(mouse_x, mouse_y, walk_speed=10, solid only)`.
  2. **Step:** obj_hero runs `MoveHero.gml` (ported line for line: 8 px per step, the shrink-while-blocked loop,
     manual wrap, 32 px grid snap on the idle axis). obj_zombie runs `action_potential_step(obj_hero.x, obj_hero.y, 2, solid only)`.
  3. **Outside room:** `action_wrap` on both axes for the hero and zombies.
  4. **Collisions:** hero+coin gives `score += 10` and destroys the coin. Hero+zombie triggers `room_restart`.
     Zombie+trap destroys both.
  - `mp_potential_step` follows GM's algorithm with the default `mp_potential_settings(30, 10, 3, true)`:
    probe goal±10° steps within the 30° max turn, look 3 steps ahead, and rotate on the spot when stuck.
  - Solids are obj_wall and obj_zombie. Collision masks come from each `.sprite.gmx` bbox
    (the hero's mask is the ellipse inscribed in its bbox).
- `direct/game.gd` + `game.tscn` draw the 1024×768 room (black, colour 0, no views)
  scaled to fit and clipped to the room. Coins draw behind everything (depth 5). obj_score draws
  `score: N` at (16,16) in GM colour 16777088 (RGB 128,255,255).
- Vendored sprites in `direct/assets/` are the original `spr_hero`, `spr_zombie`, `spr_wall`,
  `spr_trap` and `coin` PNGs.

### Faithful quirks kept
- **Score survives a room restart.** It's GM's global `score`. Being caught respawns the coins, so
  the score keeps climbing. There's no game over or win state, same as the original.
- **The mouse does almost nothing.** The hero's mouse action moves up to 10 px toward the pointer.
  Then `MoveHero` snaps any idle axis back to the 32 px grid, so on its own it gets undone in
  the same step. It's ported as written.
- **The hero can nudge 4 px into a wall's mask slack.** `MoveHero`'s loop stops shrinking at |d| ≤ 4.
- **Collisions don't wrap at the edges.** Only movement wraps, as in GM. The room places duplicate walls at x=0 and x=1024 so the edges line up visually.

### Deliberate deviations
- **Esc** opens the arcade PauseOverlay (pause, or Back to Arcade). Pausing the tree freezes the simulation.
- **Help text:** a small controls hint sits in the letterbox margin, outside the room.
- **Text:** Godot's default font, 16 px, replaces GM's default Arial 12 for the score.
- **`action_wrap`** shifts by exactly one room width or height once an instance's bbox is fully outside the room.
- **Clock:** a fixed 1/30 s step from an accumulator (max 0.25 s of catch-up) stands in for GM's frame-locked room speed.

### Not ported
- `background0.png` and `assets/floor-tile.png`. Neither is used by room0, which has no background image.
- The GM `Configs/` icons and splash screens, and the empty `help.rtf`.

`source/` holds the original project XML (`*.project.gmx`, objects, room, sprite
definitions) and `MoveHero.gml` for reference. Nothing there is loaded at runtime.

Tests: `tools/test_toroidal_zombie_herder.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A visual/UI makeover of the same room. **No rules are duplicated:**
`enhanced/game.gd` preloads Direct `tzh_world.gd` (MoveHero.gml, the
`mp_potential_step` chase, wrap, coins, traps, `room_restart`) and the generated
`room0.gd`, stepping at the same 30 steps/s accumulator. Enhanced only observes
that state and draws, so a fix in Direct lands in both editions. Still no win
state, and the score still survives being caught, as in the source. No
Alchementrix IP.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | Shell: 1280×720 letterbox stage, clipped room field, FX, HUD panels, title card, Back to Arcade |

### What changed (presentation only)
- **Stage:** room0 (1024×768) is drawn at 0.8125 into a clipped 832×624 field
  between two HUD panels. The field Control *is* the room, so the mouse maps to room
  coordinates exactly as in Direct.
- **Maze:** the grey `spr_wall` squares become crypt-stone blocks. Neighbouring walls
  merge into one mass, and only outer faces get a bevel, a moss rim and a drop shadow.
  The floor is dark flagstone with drifting graveyard fog and a lantern pool that
  follows the hero.
- **Wrap doors:** open seams on the room edge (no wall on either side, 34 of them)
  glow purple with particles drifting inward, so the torus reads at a glance. The
  hero and zombies near a seam are drawn on **both** sides (wrap ghosts), and an edge
  wrap fires portal rings at the exit and entry.
- **Sprites:** the original `spr_hero`, `spr_zombie` and `spr_trap` are kept. The hero
  gets a shadow, a lantern halo and a walk squash. Zombies shamble (wobble + bob) inside
  an aura that goes from toxic green to red as they close in, with a small chase
  arrow for their GM `direction`. Traps sit on a pulsing rune with rotating spikes.
  Coins (`coin`) become spinning, bobbing gold discs. Positions are interpolated between
  Direct steps, so movement and the grid snap look smooth.
- **Juice:** coin pickup gives sparkles, a ring and a `+10` floater. A zombie on a trap
  leaves a goo splat with a `TRAPPED!` floater and a banner. Being caught gives a red
  flash, shake, burst and a "CAUGHT!" banner. A red vignette builds as the nearest
  zombie gets within 192 px.
- **HUD:** the left panel shows score (in obj_score's colour 16777088), coins taken this
  room with a bar, zombie pips (trapped ones are crossed out), traps armed, times caught,
  time, edge wraps, and a status line when the coins or zombies run out. The right
  panel has a torus minimap (walls, coins, traps, zombies, hero, wrap doors), the
  danger meter with the nearest-zombie distance, controls and how-to-play notes.
  The original `score: N` still draws at (16,16) in the room, on a dim chip.
- **Title card:** Space/Enter or Start begins. The room doesn't step on the
  title, so the zombies wait.

### Behaviour notes
- 8 px hero steps, the shrink-while-blocked loop, the 32 px grid snap, zombie speed 2,
  `mp_potential_step` settings, wrap, collisions and `room_restart` all come from
  Direct unchanged. The test checks this against a bare Direct twin, step by step.
- **Input:** the arrows (as Direct), plus WASD as an Enhanced-only alias. Holding the
  mouse button still feeds Direct's `mouse_down` nudge.
- **R** (Enhanced only) starts a fresh run: a new Direct world (score 0) and a
  cleared shell.
- **Esc** → PauseOverlay. Pausing the tree freezes the room.
- Title `scale_mode` stays `letterbox`.

Tests: `tools/test_toroidal_zombie_herder_enhanced.gd` (run by `tools/smoke_headless.sh`).

Possible later work, which would need a rules change and so isn't in this edition:
a win state when the room is cleared, toroidal collisions and chasing across the
seams, and more rooms.
