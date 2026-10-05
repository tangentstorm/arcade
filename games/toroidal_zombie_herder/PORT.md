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

## Enhanced edition — planned (not started)
