# Cupid: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/cupid (archived), `code/` + `assets/` |
| Source commit | `3699cdfa395a9d06afe5b948f0ff0bc5f07f1d39` (master, 2010-02-12; git-svn `alchementrix/trunk/game2@761`) |
| License | none stated (tangentstorm's own repo) |
| Original | ActionScript 3 + **Flixel v1** (vendored `code/org/flixel/`, not ported), Flex `game2.mxml`, 656×350 stage, `FlxGame` pins `stage.frameRate = 90` |

## Direct edition (`direct/`): playable

- `direct/cupid_logic.gd` ports `GameState.as`, `Cupid.as`, `Person.as`, `Arrow.as`, `MatchMaker.as`,
  `MatchIcon.as`, `Music.as` and `Storm.as`, plus the bits of Flixel v1 they lean on
  (`FlxSprite` animation + `addAnimationCallback`, `FlxEmitter.emit`, `FlxG.doFollow`,
  `FlxCore.overlaps`). One `step()` is one Flixel frame at a fixed 90 Hz (`FlxG.elapsed = 1/90`).
  - **Camera:** `FlxG.follow(cupid, 1)` + `followAdjust(0.5, 0)` + `followBounds(0, 0, 1800, 350)`:
    the scroll lerps toward cupid's centre at `1·elapsed`, leads by half his x velocity, and is
    clamped to the 1800 px street.
  - **Cupid:** `velocity.x = int(mouse.x − x) · 2.5` toward the mouse's *world* x (Flixel v1
    `FlxG.mouse` is world space), y fixed at 55. Flight anim frames 0–9 at 12 fps; a click plays
    shoot `[10,11,12,10]` and the frame callback drops back to flight when it loops.
  - **Arrow:** one at a time. A click (when no arrow exists and no match icon is animating)
    drops it from the bow at `cupid.x + 42` (or `x + width − 42` facing left), `y + 72`,
    straight down at 500 px/s. It vanishes at `y ≥ 350`. Clicking aims nothing: the click
    position is ignored, exactly as `onClick(x, y)` ignored it.
  - **People:** 10 walkers, frame *i* of `pixel-people-standins-gray.png` (100×100 frames).
    MatchMaker gives symbols 0–4 shuffled, a shuffled copy as matches, so each symbol is on two
    people. They're shuffled (`length·10` random swaps) and spaced `(i+1)·163` px apart, walk
    `1.25 + floor(5·(rand−0.5))·0.1` px **per frame**, turn around 0.2 % of frames, and bounce
    off both ends of the street.
  - **Hits:** `FlxG.overlapArray(people, arrow)` with the strict bounding-box `overlaps`. The
    first hit stops the walker and shows the thought bubble, the symbol (`symbols.png` frame) and
    the glow mask; hitting a stopped person just eats the arrow. On the second hit a 1500 ms timer
    starts: same symbol → `nextLevel()` + animated heart, and after the timer both dissolve;
    different → breaking heart, and both resume walking.
  - **Win:** after `NUM_COUPLES` = 5 couples, `YOU WON!` (8 px white `FlxText` at the stage
    centre, left-aligned, as in the original).
  - **nextLevel():** level++ (the `BG_TINTS` are all `0xFFFFFF`, so tinting is a no-op), the rain
    loop gets 0.1 quieter (`Music.nextLevel`, wraps at level 6), and the storm loses a cloud. So
    every couple you make literally clears the sky a bit; after 5 the rain stops.
  - **Storm:** 5 `FlxEmitter`s, 500 recycled 128×128 `heavy-rain.png` drops each (random frame).
    `GameState.update` calls `emit()` on every live cloud **every frame** (the emitters' own
    0.7 s timer never ran because they were never added to the state). Drops spawn across the
    whole street at `y = −164`, `vx = 20`, `vy ∈ [−100, 100]`, gravity 400, and draw at the
    emitter's scrollFactor 0.33 over the sprites.
- `direct/game.gd` draws the stage scaled to fit with nearest filtering, in the original layer
  order: 5 parallax backgrounds (scroll factors 0, .2, .4, .6, .8), cupid, each person → bubble →
  symbol → mask, arrow, rain, HUD icons, then the heart crosshair (`FlxG.showCursor`, top-left at
  the mouse; the OS cursor is hidden while the game runs). The mask (`PERSON_HIT_TINT 0xFFCCCC`
  in `"screen"` blend) is precomputed once as a screen-blended copy of the people sheet.
- **Audio:** `soundloops.swf`'s `RainSound` symbol (DefineSound, 22 kHz mono MP3) was extracted
  byte-for-byte to `direct/audio/rain.mp3` and loops at `FlxG.volume 0.7 × rainLoop 0.5`, minus
  0.1 per level. (`assets/rain01.mp3` in the repo is a 0-byte file.)
- `direct/sprites/` holds the 15 original PNGs the code uses, unchanged.

### Faithful quirks kept
- The match icons never hide (`this.visible = false` is commented out in `MatchIcon.as`), so the
  last frame of the heart-with-arrow stays in the middle of the screen after the first couple.
  The breaking heart's last frame is almost empty, so it mostly disappears by itself.
- The street is 1800 px wide, but the backgrounds are 1500–1708 px; with the parallax factors
  they still cover the screen at the far right.
- The `N` key is the original's debug "next level" (one less cloud, quieter rain), kept as-is.
- Walk speed and the random turn are per frame, so they're tied to the 90 Hz step.
- Cupid isn't clamped; he can drift slightly past the street ends chasing the mouse.

### Deliberate deviations
- **Title screen.** `game2.mxml` booted straight into `GameState`. `MenuState.as` (Space →
  GameState) was there but unused, and referenced an `Assets.TitleImage` that didn't exist. This
  port uses it with the original `title.png` ("GAME 2 · PRESS SPACE TO START"), centred, and a
  click also starts (browsers need a user gesture before audio plays).
- **Play again.** After `YOU WON!`, Space starts a new game (the original just sat there).
- **Timers** are simulation time, so they freeze with the PauseOverlay; Flash `Timer`s ran on
  wall-clock time.
- **Retired rain.** Drops whose top edge is below the stage are dropped from the simulation
  (gravity only pulls them further down, so they can never be seen again).
- **Esc** opens the arcade PauseOverlay; pausing the tree freezes the simulation.

### Not ported
- `level-001.txt` (136×13 CSV tilemap) and `map_tiles.png`: `GameState` declares `map:FlxTilemap`
  but never loads it, and the only `FlxBlock` (a floor at y = 350) is off-screen and collides
  with nothing. No tilemap in Direct.
- The five `CupidSong00..04` loops in `soundloops.swf` (and `cupid-song.mid`): their `Music.as`
  code is commented out. They can be extracted the same way as the rain for Enhanced.
- Unused art: walkcycles, `victim-walk-cycle`, stores, clouds, light rays, banners, `turn-shoot`,
  `bullet`, `hero`, `zombie-test`, etc. (all kept in `source/assets/`).
- The vendored Flixel v1 library.

`source/` holds the original `code/*.as`, `game2.mxml`, `go.bat` and every file in `assets/` for
reference. It has a `.gdignore`, so Godot doesn't import it.

Tests: `tools/test_cupid.gd` (run by `tools/smoke_headless.sh`).

## Enhanced edition: planned (not started)
