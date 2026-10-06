# spiders_v_aliens

**Spiders v. Aliens** ("Ernie Goldsmile, Attorney at Law in: Spiders v. Aliens"), Michal J Wallace's
Ludum Dare 21 entry (theme "Escape", August 2011), ActionScript 3 + Flixel 2.55, built with the DAME
level editor. You wake up on the Dentists' ship: drag boxes, herd Arnaxian gut spiders into the
Dentists, fire laser cannons, carry keys to locks, ride portals, and free the mimeogeist (which copies
your every move) to reach the airlock and your ship, the *Consolas*.

- **Direct:** playable. A GDScript port of the whole game (menu, both opening scenes, the complete
  AlienShip level, game over and win screens) with the original art, font and music; see
  [PORT.md](PORT.md).
- **Enhanced:** playable. The same game and rules (it runs the Direct simulation unchanged) with a
  makeover: widescreen lit view with a smooth camera, neon/steel palette, nebula backdrop, glows and
  shadows, crisp HUD with minimap, on-screen grab prompts, restyled title/prologue/end screens and
  synthesized sound effects. See [PORT.md](PORT.md#enhanced-edition-enhanced-playable).

Source: `tangentstorm/spiders-v-aliens` (fork of `sabren/spiders-v-aliens`), archived on the box at
`/workspace/src-inventory/spiders-v-aliens/` (`as3/` is the game; `godot/` is an unfinished 2020
Godot 3 attempt). `source/` here holds the AS3 game code, DAME project, CSV maps, images and the plan.

License: none stated in the source repo (Michal's own work). The bundled `nokiafc22.ttf` is Flixel's
"system" font, shipped with Flixel (MIT).

Controls: arrow keys move; hold **W A S D** (or Dvorak **, A O E**) to grab and drag whatever is on
that side of you (machines activate when grabbed); **G** toggles the camera onto the mimeogeist;
**Space** advances menus; **Esc** pauses (arcade overlay). Enhanced adds **Enter** (skip the prologue),
**R** (retry after GAME OVER), **M** (minimap) and **H** (grab hints).
