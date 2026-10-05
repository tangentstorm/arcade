# brickslayer

Status: **planned** (Coming soon; no port yet).

Brickslayer is a Breakout-style game by Michal J Wallace, from javascriptgamer.com (2007). It is built step by step in an 11-lesson "trail".
The source was recovered from the lesson code listings on the rehosted live site. The sprites and sounds are missing.
The plan is a clean Godot 4 Direct port plus an arcade trail/lesson view (modeled on tangentcode CodeTrail).

When porting, follow games/_template/: put the faithful port in `direct/game.tscn`
and the modernized version in `enhanced/game.tscn`, then set status in
`arcade/game_registry.gd`.
