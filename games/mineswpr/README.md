# mineswpr

Minesweeper for Retro Forth 11, written by Michal J Wallace in 2013 as a
literate org file ([gitweb/mineswpr.org](https://github.com/tangentstorm/gitweb/blob/main/mineswpr.org)).
It plays on a 16×16 grid with 24 mines. You type Forth-style commands with hex
coordinates (`5 C ?`), and it draws with ANSI terminal colors.

- **Direct:** playable. A native GDScript port on an 80×25 terminal grid. You can type the original commands or use the mouse. See [PORT.md](PORT.md).
- **Enhanced:** playable. A modern Minesweeper presentation (`enhanced/game.tscn`) on a 1280×720 letterbox stage over the same Direct rules: beveled tiles, classic hint colors, flag and ripple-reveal animations, mine counter, timer, best time, and BOOM / ALL CLEAR juice. Clicks, arrow keys, and the original typed commands all work. Esc opens the arcade pause; Back to Arcade is top-left.

The source has no license file. It's tangentstorm's own work, and a reference copy is in `source/`.
