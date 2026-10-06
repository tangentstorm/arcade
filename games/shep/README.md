# shep

Status: **Direct playable**, **Enhanced playable**.

Source: https://github.com/tangentstorm/shep (`master` @ `6865ae0`). It's a Haxe 2.07 / Flash 9 game with a Flex shell and physaxe physics, published by robocognito on Kongregate (2010).
See [PORT.md](PORT.md) for the source mapping, fidelity notes, and gaps.

- `direct/game.tscn` is the faithful port. Move the mouse to steer and click to jet. Push each fuse into the socket of its color, then dock Shep in a socket before the 2:00 clock runs out. Esc opens the arcade pause.
- `enhanced/game.tscn` is a presentation makeover on the same Direct physics and levels: color-matched fuse/socket rings, aim assist, thrust trail, dock juice, side HUD, and restyled menus. Esc → PauseOverlay; letterbox; Back to Arcade.
