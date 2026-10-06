# Spiders v. Aliens: port notes

| | |
|---|---|
| Source | `tangentstorm/spiders-v-aliens` (fork of `sabren/spiders-v-aliens`), `as3/` |
| Box archive | `/workspace/src-inventory/spiders-v-aliens/` (twin: `spiders-v-aliens-main/`) |
| Source commit | `f6a2b1b52cd0a061f6f1109887fb16079865c7c6` ("dame -> godot helper tool", 2020-11-21; the AS3 code is the 2011 LD21 entry) |
| License | none stated (tangentstorm's own repo) |
| Original | ActionScript 3 + **Flixel 2.55** (vendored `as3/src/org/flixel/`, not ported), FlashDevelop `game.as3proj`, DAME level `escape.dam` → generated `dame/Level_AlienShip.as`, 640×480 stage, 60 fps fixed step |

The archive also has `godot/`, a 2020 Godot 3 restart (CSV tilemaps, `MobImporter.gd`, an
`alien.gd` stub, no gameplay). It was used only as a cross-check for the asset list; this port is a
fresh Godot 4 rewrite of the AS3 game, not a migration of that project.

## Direct edition (`direct/`): playable (complete game)

Everything the AS3 game does is in: menu → two opening "cut scenes" → the AlienShip level → game
over / win → menu.

- `direct/sva_logic.gd` ports `PlayState.as`, `SvA.as`, `Avatar/Hero/Geist`, `Grabber`, `Alien`,
  `Spider`, `Box`, `Key`, `Heart`, `Exit`, `Bullet`, `Powered/Machine/Portal/Cannon/KeyBox/SwitchBox`,
  `Narration`, `TeleType`, `MenuState`, `Opening01/02State`, `DeathState`, `WinState`, plus the parts
  of Flixel 2.55 the game depends on: `FlxObject.updateMotion` (half-step velocity, accel/drag/max),
  `separateX/separateY` (OVERLAP_BIAS 4, mass/elasticity 0, immovable), `FlxTilemap`
  `overlapsWithCallback` + `ray`, `FlxG.overlap/collide`, `FlxCamera` lock-on follow, bounds and
  `shake`. One `step()` is one Flixel frame (`FlxG.elapsed = 1/60`).
- `direct/level_alien_ship.gd` is **generated** by `source/dame_to_gd.py` from
  `Level_AlienShip.as` and the four `mapCSV_AlienShip_*.csv` files: 4 tilemaps (Outside starfield at
  scroll 0.25, Environment, Decorations, GeistWall), 158 mobiles, 34 machinery sprites, 17 object
  links (portal pairs and power wiring), 18 narration zones. (CSV is embedded as GDScript constants
  because Godot imports `.csv` as translations.)
- `direct/game.gd` draws the 640×480 stage scaled to fit (nearest), in the original draw order:
  masterLayer (Outside, Environment, Mobiles, Machinery, Decorations; GeistWall is invisible),
  grabbers, the 64 px `0xee000000` HUD with hearts and teletyped narration, then anything dispensed
  after create() (cannon bolts draw over the HUD, as in the original). Text uses Flixel's own
  `nokiafc22.ttf` "system" font, unantialiased.
- **Audio:** `sva-music.mp3` loops from PlayState on (`FlxG.playMusic`, volume 1.0 × `FlxG.volume`
  0.5) and keeps playing through game over / win / menu, restarting when a new game starts (Flixel
  music `survive = true`). The original has no sound effects (still TODO in `escapegame.org`).

### Mechanics (as in the AS3)
- Arrows accelerate ±200 (max 100 px/s, drag 750). The **mimeogeist gets the same input**; it is
  non-solid, passing through everything except the hidden GeistWall layer.
- Holding a grab key shows that side's grabber. On the press frame it activates any machine it
  touches (portal: teleport the grabber's owner to that side of the twin portal; switch: toggle;
  cannon: fire a 75 px/s bolt away from you, then reboot for 0.5 s), else grabs the last draggable
  it touches (boxes, keys, spiders, Dentists alive or dead). Held things move with you; releasing
  slings them with your velocity. Grabbing a live Dentist costs a heart.
- Dentists accelerate at 50 toward you while `layerEnvironment.ray` sees you; spiders creep at 15
  and dart away (×−2) inside 25 px. A spider touching a live Dentist kills it and dies. Bolts kill
  spiders, Dentists, and hurt you; a bolt hitting a corpse removes it.
- Touching a live Dentist (when not stunned for 2.5 s) costs a heart and reverses your velocity.
  Hearts heal one. Keys touching an unpowered KeyBox power it (and its wired portals) and vanish.
- Touching the Exit (in the airlock wall) wins. Losing all 5 hearts is GAME OVER.

### Faithful quirks kept
- Collisions run **before** motion each frame, so you're drawn up to one frame's move inside a wall.
- Dragged objects are moved with `moveTo` (which also resets `last`), so they have no delta and
  pass through walls while held; anything you drag can be pulled through a wall.
- Things held in other grabbers come along when you teleport (they catch up next frame).
- Picking up a heart calls `hurt(-1)`: it shakes the screen and gives 2.5 s of invulnerability, and
  health can exceed 5 (the HUD only shows 5).
- The "alphabetical" `typeof()` sort in `onCollide` always swaps (AS3 `typeof` is `"object"`); kept.
- `HeroShip` keeps DAME's scaled hull (240×140 at 464,1040) while the art is drawn rotated 270.2°.
- Holding Space on GAME OVER/win goes to the menu (`FlxG.keys.SPACE`), but the menu and openings
  need a fresh press (`justPressed`).
- `G` (debug camera on the geist) is kept.

### Deliberate deviations
- **Collision broad-phase:** Flixel's `FlxQuadTree` is replaced by a uniform 64 px grid. Candidate
  pairs are visited in group order, and pairs where neither object moved are skipped (separation is a
  no-op for them). The quadtree's per-node visiting order isn't reproduced, so callbacks for
  simultaneous contacts may fire in a slightly different order.
- **Esc** opens the arcade PauseOverlay (pauses the simulation and music) instead of Flixel's
  focus-loss pause (which the original disabled anyway).
- `FlxG.watch` debugger entries are dropped.

### Not ported
- `Level_Opening.as` / `mapCSV_Opening_*.csv`: generated by DAME but never instantiated by the game.
- `HeartBox`, `AvatarBox`: classes exist but none are placed in the level. Unused art (`trap`,
  `tractor`, `checkpoint`, `avatarbox`, `heartbox`) stays in `source/assets/images/`.
- The vendored Flixel library itself, `bin/` (SWF wrapper), `images.ai`.

`source/` (gdignored) holds the original `com/` AS3 code, `escape.dam`, `game.as3proj`, the CSV maps,
all images, `sva-music.mmpz` (LMMS project), the `escapegame.org` plan, and `load_sprites.py`.

Tests: `tools/test_spiders_v_aliens.gd` (run by `tools/smoke_headless.sh`): menu flow, level
contents, movement + wall stop, geist mimicry, grab/drag/release, portal teleport, key → keybox
power, switch toggle, cannon fire/reboot/kill, spider vs Dentist, heart pickup, death, exit win.

## Enhanced edition: planned (not started)
