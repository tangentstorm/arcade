# LD48: Deeper and Deeper

Status: **direct: playable**, **enhanced: playable**.

tangentstorm's Ludum Dare 48 entry (April 2021, theme "deeper and deeper"), a
short Tetraminex-universe platformer originally built in Godot 3. You play
Ernie Goldsmile, who is stuck in a hole after the "earthquake".

- `direct/game.tscn`: the faithful Godot 4 port. It starts in the intro room ("Previously..."), and the teleporter takes you on to Ivan's office.
- `enhanced/game.tscn`: presentation makeover. Same Direct rooms, Ernie physics, teleporter and dialog script (instanced, not copied); restyled chat/help chrome, juice, title card, Esc → PauseOverlay, Back to Arcade. No Alchementrix IP.
- `source/`: the original Godot 3 scripts and scenes, kept for reference
  (`.gdignore`d, so they're not imported).
- `tools/`: the Python helpers that turned the Godot 3 TileMap data into Godot 4 TileMapLayer data.

See [PORT.md](PORT.md) for the details.
