# cardinalrule — port notes

| | |
|---|---|
| Source | https://github.com/tangentscraps/cardinalrule (16 commits, 2012-11-24..25, LD25) |
| Author | tangentstorm (as sabren) |
| Pitch | README: NES-style Joust × Defender. Wide wrapping landscape, protect things on the ground from vampire bats; flap to fly, the higher of two colliding fliers wins |
| Tools | Flash Pascal (`spritetest.pas`, the build `game.html` loads), FlashDevelop + flixel (`src/*.as`, never linked) |
| Assets | `img/cardinal-r.png` (32×32, 8 colours) — the only art in the repo |
| Issue | #116 |

## What the source actually contains

1. **`spritetest.pas` → `spritetest.swf`** (the only runnable build; `game.html` embeds it at 512×448):
   - `{$FRAME_WIDTH 512} {$FRAME_HEIGHT 448} {$BACKGROUND $003399} {$FRAME_RATE 32}`.
   - Loads `img/cardinal-r.png` into a MovieClip; `onLoadInit` scales it ×2 (64×64) and puts its
     **top-left** at the stage centre (256, 224). Bounds: x 0..448, y 0..384.
   - `onKeyDown` (fires on press and on OS key repeat): Up `dy -= 4`, Down `dy += 4`,
     Left `dx -= 2`, Right `dx += 2`; PgUp/PgDn/Home/End call an empty `pass`.
     Velocity is never damped, so impulses accumulate.
   - `onEnterFrame`: `x += dx; y += dy`; clamp top/left/right (velocity kept); if below the
     floor, snap to it and `dy := 0`, else `dy += 0.2` (gravity).
   - No enemies, ground, scrolling, wrap, collisions, score, or facing flip.
2. **flixel skeleton** (`src/CardinalRule.as`, `MenuState.as`, `PlayState.as`, `Preloader.as`,
   plus `Flx.pas`/`crule.pas` Pascal bindings): `FlxGame(256, 224, MenuState, 2)` on black.
   MenuState shows "CardinalRule" (size 16, centred, y = h/2−10) and "click to play"
   (y = h−20); click → PlayState, which only shows "INSERT GAME HERE". The commit log says it
   compiled but never linked (`lib/flixel` submodule, not vendored).

## Direct edition (`direct/`)

- `bird_logic.gd`: `spritetest.pas` line for line — same start, bounds, impulses, clamp order
  and gravity; `step()` = one `onEnterFrame`.
- `game.gd` / `game.tscn`: a letterboxed 512×448 Control. Opens on the MenuState title text
  (black), click → the spritetest stage (`#003399`, cardinal at ×2, nearest filtering),
  stepped at a fixed 32 Hz.
- `img/cardinal-r.png`: the source sprite, unchanged.

### Glue added (not in the source)

- The title → play hand-off joins the two halves: the flixel MenuState screen leads into the
  Flash Pascal sprite test instead of the empty "INSERT GAME HERE" PlayState.
- Enter/Space also start from the title (the original is mouse-only).
- Fixed-timestep accumulator so motion runs at the original 32 fps on any refresh rate.
- Esc goes to the arcade PauseOverlay (arcade convention).

### Differences from the original

- Godot 4.7 instead of Flash 8; Godot's default font instead of flixel's nokiafc22 pixel font.
- Positions are floats rounded at draw time (Flash snapped `_x/_y` to 1/20 px twips).
- Key repeat comes from Godot echo events, so hold-to-repeat rate follows the OS like Flash did.
- `lib/flixel`, the FlashDevelop project and the Pascal flixel bindings are not ported (no
  behaviour of their own).

## The Decker tree (search, 2026-10-19)

Michal remembers a pixel-art tree drawn in Decker for this game. Not found; not in the port.
Searched:

- `gh search code --extension deck` under tangentstorm, tangentscraps, tangentstream,
  tangentcode (decks only in tangentstorm/tangentlabs `decker/`, tangentstorm/b4 `imp/lil/`,
  and Decker's own examples in tangentstream/lecter). `tangentstorm/decks` does not exist.
- Keyword code search for cardinal / joust / tree (until the code-search rate limit).
- Recursive git trees of all 170 repos in those four accounts for `*.deck`, `cardinal`,
  `joust`, tree images; tangentstorm and tangentstream gists (`itemlist.deck` is blank).
- Decoded every image in every tangentlabs and b4 deck (IMG0–3) to PNG and checked them by eye.
  The only "tree" cards are a binary-tree diagram (`about-bits.deck`) and tic-tac-toe game trees
  (`ttt-lesson-plan.deck`); `sawmill.deck` has a flat green triangle, not pixel art.

### Enhanced

`"enhanced": "planned"` only.
