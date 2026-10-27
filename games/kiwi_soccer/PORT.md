# kiwi_soccer — port notes

| | |
|---|---|
| Source | https://github.com/sabren/blaze, `pyweek/` (630-commit CVS import; `pyweek/` commits from 2005-08-28) |
| Event | PyWeek #1 (Aug–Sep 2005), Team Trailblazer (blazeofglory.org) |
| Title | "Kiwi Soccer" on `menu_img.png`. The window caption in `main.py` says "Kiwi Run". |
| Tools | Python 2.3+, pygame, pyODE, eventnet |
| License | No LICENSE file in `pyweek/`. The repo's other game folders ship GPL v2 (`pyweek2/`, `pyweek4/`, `Forest-Patrol/` LICENSE.txt), and the repo is Michal Wallace's (sabren). The assets are reused unchanged under that license. `direct/freesansbold.ttf` is pygame's default font (GNU FreeFont, GPL with font exception), subset to ASCII. |
| Issue | #128 |

## Credits

PyWeek team, with commit counts in `pyweek/`: **michal** (Michal Wallace, sabren) 77,
**micah** (Micah Ferrill) 79, **eykd** (David Eyk) 38, **illume** (Rene Dudfield) 18,
**dillon** (Dillon Cower) 15. Also adam (Adam Bark) 15, mario (Mario Lia) 2, plus 27 commits
by `pair` (pair-programming sessions).

The in-game credits screen (`credits.png`, "Trailblazer"):

- Team Lead: Michal Wallace (sabren)
- Programming: Michal Wallace, Micah Ferrill, Dillon Cower (Hippo), David Eyk (eykd),
  Adam Bark (pyTM30), Mario Lia (StupidMop), Rene Dudfield (illume)
- Art: Michal Wallace, Sean Siem (RenderS), yix2k, Micah Ferrill
- Story / level: Joe Peacock (JtP), yix2k, Michal Wallace, Mario Lia
- Music / SFX: Joe Peacock (JtP), Adam Bark

## What the source actually runs

I ran the original under Python 3 (fissix 2to3, Debian `python3-pygame` and `python3-pyode`)
and read the screen and the ODE state each tick.

- **States** (`main.Console`, `states.py`):
  - Menu image. Keys: P play, H high scores, E help, C credits, X exit. Hidden keys 1 and 2
    open initials entry for a 1000 or 2000 score.
  - LevelList: a black screen listing `outside` and `joe1` (size 30 font, the selected one
    white). Up/Down/Return.
  - Game.
  - Help, Credits, Scores: an image; any key returns to the menu.
- **`joe1`** has no `-geom.svg`, `-back.png` or `-fore.png`, so picking it crashes the
  original.
- **Room `outside`:**
  - Background: `data/game.png` (the 640×480 frame including the status panel) with
    `rooms/outside-back.png` blitted over its left 540×480.
  - `outside-fore.png` is fully transparent.
  - The platforms in `outside-geom.svg` are loaded as ODE boxes scaled by 1/576 (the
    `pixel2world` factor). They end up as specks near (0, 0), so nothing you see is solid.
- **Walls:**
  - `Room._setupGlass` makes front, back, left, right, top and pit boxes.
  - Only the pit is kept in a Python reference (`self.floor`). pyODE frees the others when
    their locals go out of scope, which removes them from the space.
  - The only solid surface is the floor under x 0..540, y 480..512. Run past either end and
    the kiwi falls forever.
- **Kiwi** (`hero.Bird`):
  - A 32×32 ODE box, starting at (150, 380), drawn at its rounded centre.
  - Its mass is an ODE sphere of radius 16 at density 0.0001 × fat (8,578.6 at the start).
  - `run` adds force 20 × 5,000,000 and exerts 3. `jump` adds force −8 × 5,000,000 and
    exerts 5.
  - ODE clears forces after every `world.step(0.01)`, so each is an impulse of F × 0.01.
- **Physics** (`roomphysics.py`):
  - Each tick runs two `dWorldStep(0.01)` calls.
  - Each step applies drag −50,000 × vx to the kiwi, then contacts, then gravity 98.1 px/s²,
    with world ERP 0.8 and CFM 1e-4.
  - `contact.setBounce(0.05)` has no effect, because the `dContactBounce` mode flag is never
    set.
  - `setMu(100)` without `dContactApprox1` is a constant 100-unit force cap per row.
  - For a kiwi of mass ~9,000, CFM 1e-4 turns the floor into a soft, barely damped spring
    (k ≈ 4 rows × ERP/(h·CFM)). The kiwi lands, sinks a few pixels, and bounces back up
    tens of pixels, again and again. That bouncing is most of what the game looks like.
  - The friction cap is next to nothing for the kiwi, so air drag does all the slowing.
    For the mass-1 ball the same floor is stiff, and ERP pops it high into the air.
- **Ball:** `outside-geom.svg` has no arcs, so `loader` adds the default `Ball`: a 32×32
  ODE block with ODE's default mass 1, dropped at (50, 50). In this build it is never drawn
  (see "The soccer ball" below). It falls, bounces twice and comes to rest on the floor at
  x 50. When the kiwi runs into it, it shoots off at about 1.7× the kiwi's speed (−168 px/s
  in a pyODE run where the kiwi arrives at ~100 px/s), slides off the left end and falls.
- **Controller:**
  - A key press posts the GAME event, then held keys re-post every 10 ticks.
  - The Controller that LevelList created is never released (eventnet handlers are never
    released). In the first game every press therefore posts twice: two run impulses (Δv ≈
    2 × 116 px/s), two exertions, two bips. The pyODE run shows vx 217 right after a press.
- **Metabolism** (`health.py`, defaults):
  - Start: fat 5000, blood 1000.
  - `exert(level)` burns 20 × level from blood, and any shortfall from fat.
  - Each `step()`:
    - If blood is below 100, move 5 from fat to blood.
    - Burn insulin from blood: 2, plus 10 × (blood − 1000) above the limit.
    - Add `int(insulin × 0.5)` to fat.
  - `Game.tick` also eats `Food(5, 5)` every tick ("hack to lower metabolism").
- **Status bars** (`statusbox.py`):
  - White bars 38 px wide at (549, 99) carbohydrates and (596, 99) fat stores.
  - Each is `int(376 × (1 − value/ceiling))` tall, growing down from the top. Ceilings are
    4000 for blood and 20000 for fat.
  - `statustxt.png` is drawn on top at (552, 253).
  - The kiwi keeps gaining fat, so the orange fat bar fills in over a minute or so.
- **Sound:** `1takeimprov.ogg` loops from start-up. `bip.ogg` plays on every jump event.

## The soccer ball: history

The source tree was searched for later ball, goal and kick code (`git log -p -S ball`,
`-S GOAL`, `-S soccer` over `pyweek/`; sabren/blaze has only `master` and no tags).

- **93988f2** (michal, 2005-09-03 11:04 UTC, "added soccer ball, messed with constants")
  adds `data/soccer.png` and `IMAGE.SOCCER`. The `TEST_ROOM` block in `states.Game` puts a
  32×32 block at (470, 380) and gives it a `BlockSprite` of `soccer.png`: centred on the
  rounded body position and never rotated.
- From 93988f2 until **4c6d7d2** (22:36 UTC the same day), menu P opened `Game(display)`,
  which is that test room: the kiwi and a visible soccer ball on the plain `game.png`.
  4c6d7d2 sends P to the LevelList instead, so the test room becomes unreachable. The last
  commit before the deadline is ebe2f58 (23:52 UTC).
- **aecb267** adds `CODE.BALL = 0`, `CODE.HERO = 1` ("UGLY HACK ROOMPHYSICS.COLLIDE") and
  `CODE.GOAL = 4` ("the goal for the soccer ball"), plus colours `#0000FF` (ball) and
  `#FF0000` (goal) for the SVG loader. No room SVG uses either colour, and no commit ever
  has goal, kick or scoring logic. The collide hack the comment refers to was never written.
- **1556f19** (eykd) adds `ball.py`: `room.addBlock` with size `HERO.RADIUS`, no `setMass`.
- After PyWeek, micah's `ex1.py` (2006-01-28/30) is a separate pyODE demo that blits
  `soccer.png` at an ODE sphere and pushes it with the arrow keys. d3c6d2a removes
  `ball.bmp` ("using soccer.png instead").
- Nothing else turned up: "Kick him into the other guy" is `pyweek4/`; "like a soccer field"
  in `eventtest.py` is sabren explaining eventnet; the concept SVGs talk about a flightless
  bird, food, trampolines and eggs, not soccer.
- **Outside this repo:** PyWeek 1 ran on mechanicalcat.net and pyweek.org has no pages for
  it (pyweek.org/e/Kiwi/ is another team's PyWeek 3 game). The Wayback Machine timed out
  from here. A code search of the sabren, tangentstorm, tangentscraps, tangentstream and
  tangentcode accounts finds only this repo. No final submission zip was found.

## Direct edition (`direct/`)

- **`kiwi_logic.gd`** ports these line for line:
  - `HealthModel`/`CalorieBank` (`exert`, `eat`, `step`, starve flag)
  - the bar heights
  - the Bird mass
  - the run and jump forces
  - the Controller repeat
  - Scores placement
- **`kiwi_logic.gd` `World`** re-implements the slice of pyODE this room uses:
  - The 32×32 kiwi box, the soccer ball and the static floor.
  - The ball is a round body of radius 16 (`HERO.RADIUS`) with ODE's default mass 1 and
    inertia 1, so friction at the contact point makes it roll.
  - Separating-axis box contacts, 4 rows each (dBoxBox face contact); box–circle contacts
    are 1 row (dSphereBox). Rows use the dWorldStep equations `J·v' = ERP·depth/h − CFM·λ`
    (λ ≥ 0) with a friction row capped at ±100 per row, solved by projected Gauss–Seidel.
  - Semi-implicit Euler, two 0.01 s steps per tick, forces cleared after each step.
  - The kiwi does not rotate: the ODE box stays within 0.001 rad.
- **Parity:** under the same key script as a pyODE run of the original, blood and fat match
  tick for tick. Over 260 ticks the kiwi stays within 0.7 px in x and 10 px in y (bounce
  phase drift). Kicked from rest, the ball leaves at ~1.4–2× the kiwi's speed (pyODE ~1.7×)
  and rolls off the left end, as in the pyODE run (`tools/test_kiwi_soccer.gd`).
- **Ball:** drawn with `img/soccer.png` the way the test room drew it: centred on the
  rounded body position, unrotated.
- **`game.gd` / `game.tscn`:**
  - All the states above on a 640×480 stage (`GameRegistry.fit_stage`, nearest filter,
    letterboxed).
  - Text uses pygame's own default font (`freesansbold.ttf`, subset to ASCII) at pygame's
    0.6875 size factor.
  - Ticks follow `Game.tick` at a fixed 50 Hz:
    1. `world.tick()` (2 × 0.01 s)
    2. metabolism `step`
    3. `eat(5, 5)`
    4. mass update
    5. Controller repeats
  - Key presses add forces between ticks, as eventnet did. They post twice, as in the
    original's first game.
- **Assets:**
  - `img/`: `menu_img.png`, `help.png`, `credits.png`, `high_scores.png`, `game.png`,
    `statustxt.png`, `soccer.png`, `outside-back.png` and `kiwi/{left,right}.png`, all
    unchanged.
  - `sfx/bip.ogg` is unchanged.
  - `sfx/1takeimprov.ogg` is re-encoded to mono 22 kHz Vorbis q1, from 3.4 MB to 0.35 MB
    (web size gate).
  - `tools/convert_assets.sh` regenerates them from a blaze checkout.

### Differences from the original

- A 2D re-implementation stands in for 3D pyODE: no kiwi rotation, and an iterative solve
  instead of ODE's Dantzig LCP. The bounce phase drifts by a few pixels over seconds.
- **Soccer ball:**
  - It is drawn. In the shipped build it was an invisible body: only the unreachable test
    room attached `soccer.png`.
  - It is round, as asked. The ODE geom was a 32×32 box (`addBlock`) that tumbled when
    kicked. Because the floor's ERP pop is chaotic for a mass-1 body, the round ball's
    bounces differ from pyODE's: it settles at ~10.8 s instead of ~8.1 s. The kick (fast,
    then off the end) matches.
  - It stays in `outside` at the default (50, 50). The 11:04–22:36 UTC test room, with the
    ball at (470, 380) on a plain background, is not restored.
- **No goals or scoring.** `CODE.GOAL` and the `#FF0000` colour exist, but no level has a goal
  and no code ever scored one. Enhanced could add them.
- **No glass walls (kept).** `_setupGlass`'s docstring ("glass walls holding all the data in")
  shows the intent, but since 93ee1c7 (2005-09-01) only the pit is referenced, and PyODE
  1.2.1 (2005) already destroyed unreferenced geoms. The walls never existed at runtime, so
  the kiwi and the ball still fall off either end. Sprites off the stage are clipped, as in
  pygame, not shown in the letterbox.
- The game runs at a fixed 50 ticks/s. The original had no frame limiter and ran as fast as
  the machine allowed.
- **Food:** `Food(5, 5)` also adds a new 32×32 ODE body at (0, 0) every tick. Hundreds pile
  up, trigger "LCP internal error", and fly off out of view. The calories are kept; the
  bodies are not.
- The SVG platforms are not built: in the original they are specks at the origin.
- The press doubling is the first-game case only. In the original each later trip through
  Menu → LevelList → Game leaks more handlers, so presses multiply further.
- Picking `joe1` does nothing instead of crashing.
- A score lower than every entry is appended instead of raising IndexError. The original's
  off-by-one for a new best (inserted second to last) is kept.
- High scores are saved as JSON at `user://kiwi_soccer_scores.json` instead of a pickled
  `scores` file.
- X on the menu returns to the arcade. Esc belongs to the arcade PauseOverlay.

### Enhanced

`"enhanced": "planned"` only.
