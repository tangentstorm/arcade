# Invader Sketch — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/GameSketchLib, `course/w02_InvaderSketch/demos/InvaderSketch/` |
| Source commit | `6b0de14f3db9cac10be00b00a0a879cd943c4c32` (master, 2020-11-16) |
| License | Course (game code + `invaders.png`): **CC-BY 3.0** © Michal J. Wallace. GameSketchLib (`BaseGame.pde`): **MIT** © 2011 Michal J. Wallace. Copy in `source/LICENSE.txt`. |
| Original | Processing / processing.js sketch, 640×480, on GameSketchLib (a flixel-like library inlined as `BaseGame.pde`) |

## Direct edition (`direct/`) — playable

- `direct/invader_logic.gd` is a line-for-line port of `InvaderSketch.pde` (MenuState, PlayState,
  GameOverState, WinState, ShipInvader, SpinInvader, JellInvader, Shield, HeroSprite, Bullet,
  EnemyBullet). It also ports the small part of GameSketchLib the game uses: GsTimer, GsSprite
  frame animation, `GsObject.hurt()`/`onDeath()`, and the GsGroup `update`/`overlap`/`removeDead`/
  `firstDead`/`firstAlive`/`atRandom` semantics. The rest of the library isn't ported.
- One `step()` is one Processing `draw()` frame. The game runs at a fixed 60 Hz, Processing's default
  frame rate. Movement is per frame, as in the original: the hero moves 3.5 px, enemy bullets
  1.75 px. Timers are in milliseconds and advance by whole-millisecond frames (16, 17, 17, ...)
  like `millis()`. So the fleet shifts 2 px every 7th frame, because GsTimer fires on `> 100 ms`.
- `direct/game.gd` + `game.tscn` draw the 640×480 sketch (black `background(0)`) scaled to fit,
  using the original group draw order: hero bullets, enemy bullets, hero, shields, invaders.
  Spinning invaders rotate around their cell centre. Text follows GsText: centred, baseline at `y`.
- `direct/assets/invaders.png` is the original 4×4 sheet of 50×50 cells, salvaged unchanged.

### Faithful quirks kept
- **Hero bullets move twice per frame** (3.5 px/frame). That's because GsState's group update and
  `updateHeroBullets()` both call `Bullet.update()`.
- **The ammo rack is the dead bullets.** Unfired bullets sit at `(10·i, 430)` and draw there.
  You get 3 bullets on screen at once.
- **Only the orange ShipInvaders (row 0) shoot.** The first enemy-shot tick is skipped, then shots
  come at random 0–4 s gaps. Once every ship is dead, nobody shoots.
- **Spin angle uses Java int truncation** (`int degrees += 2.5`), so steps alternate between 2° and 3°.
- **Shields take 3 hits** and darken through sheet frames 12 → 13 → 14. Both sides' bullets damage them.
- **Collision boxes are unrotated 50×50 cells.** A bullet's hitbox is its 10×15 `trueBounds`,
  and that box is refreshed only in `update()`, so it's stale for the frame a shot is fired.
- **Game over** happens when the fleet steps down to `y ≥ 380`, or when an enemy bullet hits the
  hero. **Win** happens when every invader is dead. On either screen, Space goes back to the menu.
  If both happen in one frame, the last `switchState` wins, as in the original.
- **`r`** (the original's debug key) spins a random ShipInvader to a random angle.
- **The menu link** underlines and shows a hand cursor on hover. Clicking does nothing, because
  the original had `link()` commented out.

### Deliberate deviations
- **Starts on the menu.** The shipped `setup()` had `DEBUG = true`, which skips the menu and draws a
  white box around every sprite. The port uses release behaviour (menu first, no debug boxes),
  which matches the original screenshot (`shots/InvaderSketch.png`).
- **`r` with no ships left** does nothing. The original crashed with a null pointer there.
- **Esc** opens the arcade PauseOverlay (pause, or Back to Arcade). Pausing the tree freezes the simulation.
- **Help text:** a small controls hint sits in the letterbox margin, outside the 640×480 sketch.
- **Text:** Godot's default font at the original pixel sizes replaces `DejaVuSans-48.vlw`. The
  `.vlw` isn't vendored.
- **Clock:** a fixed 60 Hz step from an accumulator (max 0.25 s of catch-up) stands in for
  Processing's `draw()` loop with a wall-clock `frameMillis`.
- **Pixel filtering:** sprites scale with nearest-neighbour filtering. The sketch is upscaled 1.5× in a 720p window.

### Not ported
- The rest of GameSketchLib (GsGrid, GsMouse tools, message protocol, Android/PJS detection) and the
  `DejaVuSans-48.vlw` font.
- The gm2-defense sprites (optional salvage). Not needed for the Direct edition.

`source/` holds the original `InvaderSketch.pde`, `BaseGame.pde`, `data/invaders.png`, and
`LICENSE.txt` for reference. It has a `.gdignore`, so Godot doesn't import it.

Tests: `tools/test_invader_sketch.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`): playable

A visual/UI makeover of the same Space Invaders clone. **No rules are duplicated:**
`enhanced/game.gd` preloads Direct `invader_logic.gd` and the Direct `invaders.png`
sheet. Menu / Play / GameOver / Win, fleet cadence, shields, the 3-bullet ammo rack
and enemy fire stay Direct. Enhanced only wraps the sim in a 1280×720 letterbox
shell and derives juice from state deltas (fleet size, shield HP, new hero bullets,
MENU↔PLAY↔GAMEOVER↔WIN).

### Visuals / UI
- 1280×720 letterbox stage; Direct 640×480 sketch @1.5× (960×720) in a clipped field
  between left/right gutter HUD panels
- Deep-space gradient + twinkling starfield; neon frame around the playfield
- Direct sheet sprites with per-kind glow (hero cyan, ships orange, spin blue, jell
  green, shields soft green); spinning invaders still rotate around cell centre
- Hero muzzle flash; glowing tracers on hero / enemy bullets; ammo rack still draws
  the dead bullets at the bottom
- Kill juice: burst + floating "+1" when the fleet shrinks; shield-hit sparks and a
  "SHIELD DOWN" floater; game-over shake/flash; win confetti burst
- Danger wash near the bottom when the fleet descends past y≈250
- Left HUD: title, state, clock, controls, Back to Arcade (`FOCUS_NONE`). Right HUD:
  invaders left, shields left, ammo, kills (view-only counter)
- Title card on boot (Space/Enter/Start); Game Over and Win cards; Space returns to
  the Direct menu (Enhanced title again). Esc → PauseOverlay

### Behaviour notes
- Input map matches Direct (←/→ A/D/E, Space shoot; `r` still spins a random ship).
  Enter aliases Space on the title / over / win cards.
- Title card holds Direct on MENU until Start; then `world.step` runs as usual.
- Esc → PauseOverlay. Title `scale_mode` stays `letterbox`.
- No Alchementrix IP. No `_enhanced` preview yet (gallery can use the Direct shot).

Tests: `tools/test_invader_sketch_enhanced.gd` (run by `tools/smoke_headless.sh`).
