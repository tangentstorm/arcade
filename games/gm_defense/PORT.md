# GM Defense — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/gamemaker-stuff (archived), `gm2-defense/` |
| Source commit | `e5416cc625283cfec90286aa396f583377d83231` ("gm2 toy project: defender clone", 2017-04-19) |
| License | none stated (tangentstorm's own repo) |
| Original | GameMaker Studio 2 project (`.yyp`): one room, two objects, three GML event files, four sprites |

## What the original is

`gm2-defense` is a toy: the first few minutes of a Defender clone. The whole game logic is:

| Object | Event | Code |
|---|---|---|
| `o_ship0` (sprite `s_ship0`) | Create | `speed=5` |
| | Key Press ← (37) | `direction = 180; image_xscale = -1` |
| | Key Press → (39) | `direction = 0; image_xscale = 1` |
| `o_squid` (sprite `s_squid`) | *(none)* | sits there and plays its 4-frame animation |

`r_main` is 1024×768 with a black background layer and views off. It places `o_ship0` at (320,416)
and `o_squid` at (352,288). There's no shooting, no collisions, no score, and no Outside Room event.

## Direct edition (`direct/`): playable

- `direct/gmd_world.gd` simulates `r_main` at the GMS2 default game speed (60 steps/s). Each step follows GM's event order:
  1. **Key Press** events. ← sets direction 180 and flips the sprite. → sets direction 0 and unflips it.
  2. **Built-in motion:** `x += lengthdir_x(speed, direction)`, `y += lengthdir_y(...)`.
  3. **Sprite animation:** `image_index += 5/60` for `s_squid`. Its `playbackSpeed` is 5 at type 0, which means frames per second.
- `direct/game.gd` + `game.tscn` draw the room scaled to fit and clipped to its bounds. Both sprites are 50×50 with a centred origin.
  Key Press events are queued from `_unhandled_input` and consumed on the next step, so a tap between steps still registers.
- Vendored sprites in `direct/assets/`: `s_ship0_0.png` and `s_squid_0..3.png`. These are the composite frame PNGs, in the frame order from `s_squid.yy`.

### Faithful quirks kept
- **The ship moves on its own from frame one.** `speed=5` and the default direction of 0 send it right immediately.
- **The arrows turn the ship. They don't thrust.** It's a Key *Press* event, so holding the key does nothing extra. The ship never stops.
- **The ship can leave the room.** There's no wrap or clamp. At 5 px/step it goes off-screen in about 2 s. Press the opposite arrow to bring it back.
- **The squid is inert.** It has no events and no collision.

### Deliberate deviations
- **Esc** opens the arcade PauseOverlay (pause, or Back to Arcade). Pausing the tree freezes the simulation.
- **Help text:** a small controls hint sits in the letterbox margin, outside the room.
- **Clock:** a fixed 1/60 s step from an accumulator (at most 0.25 s of catch-up) stands in for GM's frame-locked game speed.
  The project's `options_main` sets no game speed, so the GMS2 default of 60 fps is assumed.

### Not ported / cuts
- `s_ship1` (orange ship) and `s_triclops` (green 2-frame alien) are defined in the project but no object uses them, so they aren't vendored.
- `invaders.png` is the 200×200 source sheet the sprites were cut from, so it isn't loaded either.
- `views/`, `options/` and other GMS2 IDE metadata.

`source/` holds the original `.yyp`, object `.yy` + `.gml` events, the room and the sprite definitions,
for reference. Nothing there is loaded at runtime.

Tests: `tools/test_gm_defense.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition: planned (not started)

The obvious direction is to finish the Defender clone the sprite sheet hints at: wrap-around scrolling,
thrust, lasers (the sheet has bullet sprites), triclops/squid waves, and the second ship as player two.
