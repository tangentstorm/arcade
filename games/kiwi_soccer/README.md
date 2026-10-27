# Kiwi Soccer

Team Trailblazer's first PyWeek entry (PyWeek #1, Aug–Sep 2005), written in pygame and pyODE.
A kiwi runs and hops along the bottom of the "outside" room. Its weight comes from a working
metabolism: running and jumping burn blood sugar ("carbohydrates"), insulin moves sugar into
"fat stores", and fat sets the kiwi's mass. The game was never finished: there are no goals,
eggs or food to pick up. The soccer ball was in the physics but never drawn in the
shipped build; this port draws it with the original `soccer.png`, and the kiwi can knock it
off the end of the floor.

See [PORT.md](PORT.md) and arcade issue #128.

- **Direct:** a Godot 4 port of what the source runs. Menu (P play, H high scores, E help,
  C credits, X exit), the level list, then the room: arrow keys run, Space jumps, X goes back
  to the menu.
- **Enhanced:** planned.
