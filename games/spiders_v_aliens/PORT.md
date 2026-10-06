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

## Enhanced edition (`enhanced/`): playable

A visual/UI makeover of the same game. **No rules are duplicated:** `enhanced/` preloads
`direct/sva_logic.gd` (simulation), `direct/level_alien_ship.gd` (generated level) and the Direct
sprites, font and music, and steps the simulation exactly as Direct does (fixed 60 Hz, same input
names). Everything Enhanced adds is read-only presentation, so puzzle logic, physics quirks, the
level, narration and win/lose conditions are byte-for-byte the Direct edition's, and a rules fix in
`sva_logic.gd` lands in both editions.

| File | Role |
|---|---|
| `enhanced/game.gd` | Root: input, fixed-step loop, camera, music, state changes, SFX event diffing, QoL keys |
| `enhanced/stage.gd` | World view `SubViewport`: TileMapLayers built from the level data, sprite drawing, lights |
| `enhanced/hud.gd` | Native-resolution HUD and screens (title, prologue, play, GAME OVER, win), minimap |
| `enhanced/hints.gd` | Read-only "what would this grab key do?" queries used for prompts and outlines |
| `enhanced/sfx.gd` | Synthesized SFX (16-bit PCM generated at startup; no new audio assets) |
| `enhanced/lighting.gdshader` | Per-pixel lighting (32 world-space lights) + palette regrade + emissive neon |
| `enhanced/stars.gdshader`, `backdrop.gdshader` | Starfield twinkle (black keyed out) and nebula backdrop |

### What changed (presentation only)
- **View:** 854×480 widescreen world view (Direct: 640×480 with a 64 px HUD strip over it), with
  its own camera: smoothed follow with slight look-ahead, snapping on long jumps, clamped to the same
  2560×2000 bounds; screen shake from the simulation is applied at 0.75×. The sim's own `scroll_x/y`
  (Flixel's 640×480 lock-on camera) is ignored; it never affects gameplay.
- **Crisp scaling:** the view is rendered at an integer multiple of the world texel size (chosen from
  the physical window size) and downsampled with linear filtering, so pixels stay even at the
  arcade's 1.5× letterbox instead of the nearest-neighbour 1px/2px pattern.
- **Lighting & palette:** dark-blue ambient; light from the 17 fluorescent fixtures in the
  Decorations layer, a warm lantern on Ernie, violet on the mimeogeist, green on powered portals /
  switches / unlocked keyboxes, red on locked boxes and cannon bolts, gold on keys, pink on hearts,
  green on the exit. Grey deck plating is regraded to cool steel, wall trim glows neon cyan, tubes
  and conduits are emissive. Floor halos and additive bolt flares; soft drop shadows under mobiles;
  held objects lift slightly; Ernie blinks while stunned; the geist is translucent.
- **Backdrop:** procedural nebula + dust stars behind the original parallax starfield (its opaque
  black is keyed out; stars twinkle). The title and prologue drift over the dimmed ship.
- **HUD (native 1280×720, nokiafc22 at integer sizes):** large hearts (pulse at 1 HP, `+n` above 5),
  locks opened / live Dentists / run time, narration in a framed panel with Ernie's portrait and a
  teletype cursor, a "MIMEOGEIST CAMERA" banner while `G` is active (the hidden GeistWall is
  faintly shown then), and a fog-of-war **minimap** (keys, locks, exit, geist, camera frame).
- **Grab prompts (QoL):** for whichever avatar the camera follows, each grab key that would do
  something shows a keycap + label beside the target ("Drag crate", "Teleport", "Portal offline",
  "Fire east", "Cannon recharging", "Locked: bring a key", red "Dentist! Grabbing bites"...) and the
  target gets a pulsing outline. `hints.gd` mirrors PlayState's press-frame order (first machine
  touched wins, else the last draggable) and never mutates the world.
- **Screens:** restyled title (cast lineup, controls card, `< Back to Arcade` button that never takes
  keyboard focus), framed two-part prologue with the original art at 2×, GAME OVER card over the
  frozen red-tinted scene with time and Dentists downed, win card with the *Consolas* flying off.
- **Audio:** same music, plus synthesized SFX for grab/drop, teleport, switch, unlock, cannon,
  hurt, heal, Dentist down, win and game over (detected by diffing the simulation each frame).
- **QoL keys** (handled outside the simulation): **Enter** on the title or prologue starts a fresh
  run in the ship; **R** on GAME OVER retries immediately (Space still goes to the title, as in
  Direct); **M** toggles the minimap; **H** toggles grab prompts.
- Esc → arcade PauseOverlay (pauses simulation and audio); letterbox scale mode; gallery uses
  `arcade/previews/spiders_v_aliens_enhanced.png` for this edition.

### Fidelity note
Rules, level data, timing and every Direct quirk listed above are unchanged because they are the
same code. Visible differences are view-only: a wider/taller field of view (you can see a little more
of neighbouring rooms than the 640×416 Direct view), a smoothed camera instead of Flixel's hard
lock-on, and on-screen information the original left to discovery (prompts, minimap, counters).
Prompts are computed from current positions without the swept-hull test, so in rare frames
mid-motion a prompt can differ from what the press actually hits.

### Deferred polish
- Openings are restyled screens around the original 270×260 art, not re-drawn or animated scenes.
- No re-drawn sprites or new tiles; the makeover is lighting/palette/UI over the 2011 art.
- No options menu (volume, shake, hint/colour settings); toggles are keys only and not persisted.
- No touch / gamepad controls.
- No checkpoints: R restarts the whole ship (the original has no checkpoints either).

Tests: `tools/test_spiders_enhanced.gd` (run by `tools/smoke_headless.sh`): registry entry, scene
load + stage build (tile layers, fixtures, lights), title → prologue → Enter skip, hero move via the
scene's input path + camera follow, grab prompt + crate drag, portal prompt + teleport + SFX, locked
portal prompt, hurt / GAME OVER / R retry, win → title, paused tree freezes the sim, M/H toggles.
