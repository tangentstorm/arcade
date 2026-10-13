# tankgame — port notes

| | |
|---|---|
| Source | https://github.com/tangentscraps/tankgame (Rails + Opal + Phaser 2) |
| Author | tangentstorm |
| Pitch | Artillery-tank prototype: random sand terrain, two tanks |
| Issue | #104 |

## Mechanics brief (original `app/assets/javascripts/game_view.js.rb`)

- 800×600 Phaser stage: `background.png`, then a ground tilemap, then 2 tanks.
- Terrain: 81×61 bit grid. A random walk starts at `MH/2`, moves `rand(3)-1` once per
  column; cells below the level are sand (1).
- Rendering: 80×60 tiles of 10×10 px. Each tile = marching-squares index
  `TL<<3 | TR<<2 | BR<<1 | BL` into the 16-tile strip `msquares.png`.
- Tanks: for i in 0..1, `gun{i}` at (i·200+225, 303), then `tank{i}` at (i·200+200, 300).
  They are fixed sprites; they do not follow the terrain.
- No input, movement, firing, physics or win state. `bullet.png` is loaded nowhere in code.

## Direct edition (`direct/`)

- Same sprites (copied from `public/sprites/`), same terrain algorithm and positions,
  letterboxed 800×600 with nearest-neighbor filtering.
- `direct/tank_logic.gd`: pure terrain grid + `msquare`; seedable for tests.
- `direct/game.gd` / `game.tscn`: draws the background, tiles and tanks.

### Differences from the original

- Added **R** to regenerate terrain (the original only re-rolls on page reload).
- Godot RNG instead of Ruby `rand`, so a given layout cannot be reproduced exactly.
- Esc goes to the arcade PauseOverlay (arcade convention).

### Enhanced

`"enhanced": "planned"` only.
