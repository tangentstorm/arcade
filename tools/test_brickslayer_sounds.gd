extends SceneTree
## Brickslayer sounds: the five 2006 mp3s load, and each game event plays the
## sound the original wires to it (snap/final/brickslayer.js).
## Run: godot --headless --path . --script res://tools/test_brickslayer_sounds.gd

const Logic := preload("res://games/brickslayer/direct/brickslayer_logic.gd")
const SCENE := "res://games/brickslayer/direct/game.tscn"
const FILES := {
	"serve": "whish.mp3", "hit": "plopp.mp3", "break": "glass2.mp3",
	"bounce": "boing.mp3", "fall": "deepsplosh.mp3",
}
const STORE := "user://test_brickslayer_sounds.cfg"

var _fails := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("SMOKE FAIL: brickslayer sounds: ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var view = load(SCENE).instantiate()
	root.add_child(view)
	await process_frame
	for key in FILES:
		var p = view._sounds.get(key)
		check(p is AudioStreamPlayer, "%s player exists" % key)
		if p:
			check(p.stream is AudioStreamMP3, "%s stream is mp3" % key)
			check(p.stream.resource_path.ends_with("sounds/" + FILES[key]), "%s -> %s" % [key, FILES[key]])
			check(p.stream.get_length() > 0.05, "%s has audio (%.2fs)" % [key, p.stream.get_length()])
	# Each event emits exactly the original's sound id, and the view plays it.
	var g = view.game
	var heard: Array = []
	g.sound.connect(func(n): heard.append(n))
	g.swap("game")
	g.tick()
	g.serve(0.25, Logic.SERVE_SPEED)
	expect(view, heard, "serve", "serve (Ball.launch)")
	g._brick_hit(g.bricks[4])             # shade 5 -> 4
	expect(view, heard, "hit", "brick shade drop (Brick.onHit else)")
	g._brick_hit(g.bricks[0])             # shade 1 -> gone
	expect(view, heard, "break", "brick destroyed (Brick.onHit)")
	g.ball.set_x(2); g.ball.set_y(200); g.ball.dx = -3; g.ball.dy = -1
	g._check_walls()
	expect(view, heard, "bounce", "side wall (checkWalls)")
	g.ball.set_x(100); g.ball.set_y(2); g.ball.dx = 0; g.ball.dy = -4
	g._check_walls()
	expect(view, heard, "bounce", "ceiling (checkWalls)")
	g.ball.set_x(g.paddle.x + 20); g.ball.set_y(g.paddle.y - 17); g.ball.dx = 0; g.ball.dy = 4
	g._check_paddle()
	expect(view, heard, "bounce", "paddle (checkPaddle)")
	g.lose_life()
	expect(view, heard, "fall", "ball into the lake (loseLife)")
	# Before lesson 07 the game is silent, as on the trail.
	var g6 = Logic.new(6, STORE)
	var quiet: Array = []
	g6.sound.connect(func(n): quiet.append(n))
	g6.lose_life()
	check(quiet.is_empty(), "lesson 6 is silent")
	g6.dispose()
	view.free()
	await create_timer(0.5).timeout       # the mix thread drops stopped playbacks
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("brickslayer sounds tests: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails else 0)


func expect(view, heard: Array, name: String, what: String) -> void:
	check(heard == [name], "%s plays %s (got %s)" % [what, name, heard])
	var p = view._sounds.get(name)
	check(p != null and p.has_stream_playback(), "%s: %s player started" % [what, name])
	for q in view._sounds.values():
		q.stop()
	heard.clear()
