# Kill 'Em All — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/gamemaker-stuff (archived), `killem-all.gmx/` |
| Source commit | `e5416cc625283cfec90286aa396f583377d83231` (master, 2017-04-19) |
| License | none stated (tangentstorm's own repo) |
| Original | GameMaker: Studio 1.x project (`KillemAll.project.gmx`): one room, four objects, three GML scripts, one font |

## What the original is

It's a twin-stick shooter prototype, with the title written before any enemies existed. `room0` (1024×768, colour 1835008 = dark navy, speed 30, no views) holds:

| Object | Sprite | Role |
|---|---|---|
| `objShip` | `sprite1` (64×64 grey disc) | the player. It has no events of its own and is driven by `step.gml` |
| `objBlast` | `sprite0` (64×64 white arc) | the gun/shield arc. It's glued to the ship and rotated toward the mouse |
| `events` | `spr_mouse` | controller: Create → `init.gml`, Step → `step.gml`, Draw → `mousepos.gml` |
| `objBullet` | `bullet` (8×8) | no events. `step.gml` creates one per step with `speed = 10` |

## Direct edition (`direct/`): playable

- `direct/ka_world.gd` simulates room0 at 30 steps/s. `_step_script()` is `scripts/step.gml` ported line for line:
  - **Heading** comes from the four keys. Thrust is `dx += cos(a)`, `dy += sin(a)` with `a = arctan2(hy, hx)`. Each axis is clamped to ±10.
    With no key held, the ship coasts with `dx, dy *= 0.99`.
  - **Aim:** `objBlast.image_angle = point_direction(ship, mouse)`. The arc follows the ship.
  - **Fire** happens while the left button is held, so you get one bullet per step (30/s). Each bullet spawns 30 px out along the aim.
    It moves 10 px/step, starting in the same step, because GM updates positions after the Step event. Every shot gives a 0.05 kickback away from the aim.
  - `init.gml` runs at room start. It centres the ship at (512,384). `objBlast` stays at its room spot (480,416) until the first step.
- `direct/game.gd` + `game.tscn` draw the room scaled to fit and clipped to its bounds:
  the ship disc, then the rotated arc, then the bullets. `events`' Draw event runs `mousepos.gml`,
  which writes `x:<mouse_x>, y:<mouse_y>` at (10,10) in white. A Draw event replaces the default sprite draw, so `spr_mouse` is never visible.
- **Text uses the original font.** `assets/fntConsolas.png` is GM's pre-rendered Consolas 12 atlas, and
  `direct/ka_font.gd` holds the glyph table, generated from `source/fonts/fntConsolas.font.gmx`.
  Glyph cells are placed as GM 1.x does: at the line top, offset by the bearing, advanced by `shift`.
- Vendored sprites in `direct/assets/`: `sprite0_0.png`, `sprite1_0.png`, `bullet_0.png`, plus `spr_mouse_0.png` (kept for completeness, never drawn).

### Controls
`step.gml` reads `ord('A')`, `ord('E')`, `188` (`,`) and `ord('O')`. That's WASD for a **Dvorak** typist.
The port reads those keys by **physical** position (W A S D on a US layout), so they land under the same
fingers on any keyboard layout. It also accepts the literal A / E / , / O keycodes the GML names, and the arrow keys.

| Action | Keys |
|---|---|
| thrust left / right / up / down | A / D / W / S (physical), or ← → ↑ ↓ |
| aim | mouse |
| fire | hold left mouse button |
| pause / back to arcade | Esc |

### Faithful quirks kept
- **No enemies, no score, no collisions.** It's "Kill 'Em All" with nobody to kill, as in the source.
- **No walls.** There's no Outside Room event, so the ship can drift out of the room for good unless you thrust back. Recoil alone will push it out eventually.
- **Inertia:** the ship only slows by 1% per step when coasting. Opposite thrust stops it faster.
- **The mouse readout** (`x:…, y:…`) is the original's debug HUD. It shows room coordinates, so it goes negative in the letterbox margins.

### Deliberate deviations
- **Esc** opens the arcade PauseOverlay (pause, or Back to Arcade). Pausing the tree freezes the simulation.
- **Help text:** a small controls hint sits in the letterbox margin, outside the room.
- **Bullets are culled 64 px outside the room.** GM keeps every `objBullet` forever, which is 30 instances a second with nothing to destroy them.
  They can't come back, since they fly straight with no views, so there's no visible difference.
- **Clock:** a fixed 1/30 s step from an accumulator (at most 0.25 s of catch-up) stands in for GM's frame-locked room speed.

### Not ported / cuts
- **room0's creation code** calls `draw_text(… "LEVEL 1")`. Draw calls outside a Draw event don't show in GM:S 1.x, so the original never displays it. The port leaves it out too.
- `scripts/script1.gml` is empty. `help.rtf` is empty. The `Configs/` installer icons, splash screens and signing keys aren't ported.

`source/` holds the original project XML (`*.project.gmx`, objects, room, sprite and font definitions)
and the GML scripts, for reference. Nothing there is loaded at runtime.

Tests: `tools/test_killem_all.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition: planned (not started)

Natural next steps: enemies to actually kill, bullet/enemy collisions, a score, a bounded or wrapping arena, and gamepad twin-stick input.
