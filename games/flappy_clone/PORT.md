# Flappy Clone — port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/unitylabs (`flappyclone/`) |
| Source commit | `f25ce4ec2ae30b762437aebcb7c4837bad585980` ("implement scoring", 2015-03-11) |
| Engine | Unity 5.0.0f4, 2D (Rigidbody2D/Box2D, uGUI) |
| License | No LICENSE in the source repo. Code and art are tangentstorm's own work. |
| Tracking | GitHub issue #2 |

## Direct edition (`direct/`) — playable

- `direct/flappy_logic.gd`: the simulation in original Unity units (+y up, camera
  at the origin, 6.72 u tall view). It ports the `screens.controller` state machine
  (Title → Intro → GamePlay → GameOver → Intro), `BirdController`, `GameWorld`, and
  `Scrolling`/`ScrollLayer`. All values come from `main.unity`: gravity 9.81, bird
  start (0.16, 0.15) with r 0.29, pipes 1.45×3.41 u at y ±2.5 (gap centered on 0),
  gates every 8 u from x 4, endZone 0.75 u past the pipe, floor top −2.55,
  ceiling bottom 3.31, and +10 per endZone exit.
- `direct/game.gd` + `game.tscn` draw the vendored `direct/assets/clonybird.png` atlas.
  The 16 slices are the regions from `clonybird.png.meta`, at 90 px/unit with
  center pivots. Each sprite sits at its `main.unity` position. Parallax uses the
  original layers: sky ×0.05 every 7 u, city ×0.2 every 10 u, and ground/pipes ×1
  every 5 u / 8 u. The UI copies the uGUI canvas: shade (0.07, 0.03, 0.03, 0.56),
  79 pt "Flappy Clone" / "Game Over" with a 100×100 Play button, and a top-right
  20 pt "score:" label. The camera background color is the same too.
- Kept faithfully (original quirks):
  - **Two BirdControllers** on the bird (flapForce 2.5 and 5). Each press *adds*
    7.5 to vy, and the scripted first flap adds 2.5.
  - Impulses add to velocity instead of setting it.
  - Every gate has the same gap at y = 0, with no randomization.
  - The world scrolls on the title and game-over screens too, and the pipes
    are never hidden.
  - The ceiling is solid but harmless. The floor and pipes end the run, and the
    bird is hidden on game over.
  - The score label shows on title/game over and hides during the Intro hold.

### Deliberate deviations
- **Delta-time:** scrolling is 3 u/s, which is 0.05 u/frame at 60 fps. The original
  moved per frame. Physics runs at a fixed 50 Hz step, like Unity FixedUpdate.
- **Collision:** hand-rolled circle-vs-box tests replace Box2D. The bird doesn't
  spin from contacts. In the original, FixedAngle was off, so a ceiling hit could
  rotate it.
- **Flap sprite** shows for 0.1 s per flap. The original Animator flashed it for
  about one frame.
- **Input:** Space (Unity "Jump"), plus left click / touch for web and mobile. The
  Play button gets focus, so Enter/Space also presses it.
- **Additions:** a "Back to Arcade" button (→ `GameRegistry.return_to_arcade`) and a
  small "space / click / tap to flap" hint during Intro. Esc opens the arcade
  PauseOverlay (resume / Back to Arcade).
- Parallax tiles copies to cover any aspect ratio (the arcade window is 16:9). The
  original kept 3 leapfrogging copies sized for 4:3. Godot's default font replaces
  Arial, and the Play button uses the default Godot theme.

### Not ported
- Dead Animator states (HighScore, Scores, Credits) and their unused triggers.
- `.unity`/`.controller`/`.anim` YAML (values captured above).

`source/` holds the original C# scripts and `clonybird.svg` (the editable
Inkscape source of the atlas) for reference. It has a `.gdignore` and isn't part
of the export.

Tests: `tools/test_flappy_clone.gd` (picked up by `tools/smoke_headless.sh`).

## Enhanced edition (`enhanced/`) — playable

A modern makeover of the same game. It keeps the Direct world units, gravity,
scroll speed, bird size, floor and ceiling, so a flap still has the same arc
and weight. Everything is drawn procedurally. There are no new assets.

- `enhanced/flappy_enhanced_logic.gd` is the simulation. It has 5 states:
  Title, Ready, Play, Dying and Over. Gates are a list of `{x, gap_y, scored}`
  instead of Direct's infinite fixed-gap repeat. It emits events (flap, score,
  hit, land, over, ready) that the view uses for effects.
- `enhanced/game.gd` + `game.tscn` draw a fixed 1280×720 stage (107 px/unit).
  The stage has a gradient sky with a sun, parallax clouds (×0.08), a city
  silhouette with lit windows (×0.25, a nod to Direct's buildings), hills (×0.5),
  and a striped grass ground (×1). Pipes have caps and shading. The bird tilts with
  vy, squashes on each flap, flaps its wings and leaves feather puffs. It gets X eyes
  when it crashes.
- UX: Title (Play) → Ready (the bird bobs, "space / click / tap to flap") → Play. A
  crash shakes the screen and flashes white. The world freezes while the bird drops,
  bounces once and settles on the ground. The Game Over card then slides in with the
  score, the best score and a "New best!" badge. Taps are ignored for 0.45 s, then
  space / click / tap or "Play again" restarts straight into Ready. The best score is
  saved to `user://flappy_clone_enhanced.cfg`.
- The score is a big outlined number at the top. It pops (×1.45, gold) on each gate.
- Esc opens the arcade PauseOverlay. Scale mode is `letterbox`, shared with Direct.
  "Back to Arcade" sits top-left, as in Direct.

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Flap | adds 7.5 to vy (two BirdControllers); first flap adds 2.5 | sets vy = 4.4 (apex ≈ 1 u), every flap the same |
| Fall | unbounded | capped at −8 u/s |
| Physics step | 50 Hz | 120 Hz |
| Bird x | 0.16 (center) | −1.6 (more look-ahead) |
| Gates | every 8 u, gap always at y = 0, half-gap 0.795 | every 5 u; the first gap is at y = 0, then random in [−1.15, 1.6], ±1.5 max per gate; half-gap 0.92 |
| Hitbox | r 0.29 | r 0.24 (drawn r 0.29) |
| Score | +10 on endZone exit | +1 once the bird clears the pipe; pop animation; best score saved |
| Crash | bird hidden, Game Over at once | world freezes, bird falls and lands, Game Over card after 0.35 s on the ground |
| Pipes on title | shown, scrolling | none until the run starts |
| Restart | Play button → Intro | tap / space / Enter / ↑ / W or "Play again" after a 0.45 s lockout |
| Art | `clonybird.png` atlas | procedural `_draw` and StyleBoxFlat |

Kept from Direct: gravity 9.81, scroll 3 u/s, view 6.72 u tall, floor −2.55
(deadly), ceiling 3.31 (solid but harmless), bird radius 0.29, and the world
scrolling on the title screen.

Tests: `tools/test_flappy_enhanced.gd`. It covers the registry entry, launch, letterbox
aspect, space → Ready → Play, Esc pause and return, flap/gravity values, the ceiling,
pipe spawn spacing and fairness, scoring, the pipe-hit → land → Game Over path,
the restart lockout and the best score.
