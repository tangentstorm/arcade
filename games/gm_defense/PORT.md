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

## Enhanced edition (`enhanced/`): playable

A visual / UI makeover of the same toy. **No rules are duplicated:** `enhanced/game.gd` preloads
`direct/gmd_world.gd` and the Direct sprites, queues the same Key Press edges (← / →, echo ignored)
from `_unhandled_input`, and steps the world at the same fixed 60 steps/s with the same 0.25 s
catch-up cap. Every faithful quirk stays: the ship launches on frame one, never stops, can leave
the room, and the squid is inert. Juice uses its own RNG and only reads world state. No Alchementrix IP.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | 1280×720 letterbox shell: clipped room view, HUD, radar, juice, SFX |

### What changed (presentation only)
- **Stage:** fixed 1280×720 stage (`letterbox`). `r_main` (1024×768) draws at 0.75× as a
  768×576 field, clipped to the room, with corner brackets, a title bar, side panels and a
  radar strip.
- **Room:** the plain black background becomes a deep-space gradient with soft nebulae, three
  depths of twinkling parallax stars that drift against the ship's heading, faint scanlines,
  and a purple synthwave horizon grid along the bottom fifth of the room (decor only; nothing
  collides with it).
- **Sprites:** the Direct ship and squid frames draw 1:1 (crisp 50 px, nearest filter) centred
  on their scaled room positions, rather than at 0.75×, which would leave uneven pixels.
- **Ship:** cyan glow, a floor reflection, exhaust sparks out of the rear and fading
  afterimages. On a turn, the sprite does a quick banking flip (its x-scale eases through
  zero instead of snapping) with a ring, sparks, a "◀ TURN" / "TURN ▶" floater and a blip.
- **Squid:** pulsing magenta halo, a soft shadow and bubbles that rise as its Direct frame
  advances. The 4-frame animation is Direct's `image_index`.
- **Off-room locator:** Direct has no wrap or clamp, so once the ship leaves the room a
  pulsing red chevron sits on the field edge at the ship's row, showing how many room pixels
  away the sprite is. While the ship is still heading away it adds "press ◀/▶ to come back".
  You get an "OUT OF ROOM" floater on exit and a gold burst and "BACK!" on re-entry.
- **Radar:** the strip under the field covers one room either side of `r_main`, with the room
  window, the squid and the ship plus a heading tick. Past that range the ship pins to the
  edge in red ("beyond radar").
- **HUD:** heading, x/y, in room / off N px, time, turns, distance flown and room exits on the
  left; controls and a short "it's a toy" note on the right. A non-blocking "LAUNCH!" banner
  fades after about 3 s (Direct has no title screen, so the ship isn't held). Esc opens the
  arcade PauseOverlay; "Back to Arcade" is top-left and never takes keyboard focus.
- **Audio:** small synthesized blips (turn, leave room, back in room). The original has no audio.

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Rules / sim | `gmd_world.gd` | same script (preload), no copy |
| Input | Key Press ← / → queued to next step | same |
| Stage | 1024×768 room scaled to fit | 1280×720 chrome around a 0.75× clipped field |
| Look | black room, raw sprites | space gradient, stars, horizon grid, glows, 1:1 sprites |
| Off-room ship | just gone | edge locator + distance + radar |
| Esc / Back | PauseOverlay | same + explicit Back to Arcade (FOCUS_NONE) |

### Deferred
- The bigger Defender ideas (wrap-around scrolling, thrust, lasers from the sheet's bullet
  sprites, triclops/squid waves, `s_ship1` as player two) would be new mechanics, so they're
  out of scope for a makeover.
- No dedicated Enhanced gallery preview in this PR (the card uses the Direct shot).

Tests: `tools/test_gm_defense_enhanced.gd` (run by `tools/smoke_headless.sh`): the script compiles,
Direct logic ownership, a 1200-step key session (taps, a same-step left+right, echoes and
releases) fed through Enhanced's `_unhandled_input` + `_process` and compared every step against
a bare Direct twin, leave/return coverage, turn and exit counters, registry entry, launch +
letterbox, frame-one launch, Back to Arcade FOCUS_NONE, a real Left key → Direct flip + turn
juice, off-room distance, Esc → PauseOverlay freezes the sim, and Esc again → arcade.
