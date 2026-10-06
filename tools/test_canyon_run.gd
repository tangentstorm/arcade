extends SceneTree
## Headless checks for Canyon Run Direct: scene loads, craft steers, canyon scrolls,
## wall crash + reset path, bullets kill drifters.
## Run: godot --headless --path . --script res://tools/test_canyon_run.gd

const SCENE := "res://games/canyon_run/direct/game.tscn"
const Logic := preload("res://games/canyon_run/direct/canyon_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: canyon_run ", msg)
	else:
		print("SMOKE FAIL: canyon_run ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_logic_checks()
	await _scene_checks()
	quit(1 if _fail else 0)


func _logic_checks() -> void:
	var g = Logic.new(7)
	_check(g.state == Logic.State.READY, "starts on the ready screen")
	g.update(1.0)
	_check(g.dist == 0.0, "no scrolling before the run starts")
	g.start()
	_check(g.state == Logic.State.PLAY, "start -> play")
	var w0: Vector2 = g.walls_at(g.player_world_y())
	_check(w0.x < g.player_x and g.player_x < w0.y, "craft starts inside the channel")
	g.update(0.5)
	_check(g.dist > 30.0, "canyon scrolls (dist=%.1f)" % g.dist)
	_check(g.row_count() > 0, "canyon rows generated")
	var x0: float = g.player_x
	g.update(0.2, -1.0)
	_check(g.player_x < x0, "steer left moves the craft left")
	x0 = g.player_x
	g.update(0.2, 1.0)
	_check(g.player_x > x0, "steer right moves the craft right")
	var s0: float = g.speed
	g.update(0.3, 0.0, 1.0)
	_check(g.speed > s0, "throttle up speeds up")

	# Fly 20 s down the centre of the channel with a simple autopilot: no wall crash.
	var t := 0.0
	g.enemies.clear()
	while t < 20.0 and g.state == Logic.State.PLAY:
		var w: Vector2 = g.walls_at(g.player_world_y() + 20.0)
		var mid := (w.x + w.y) * 0.5
		g.enemies.clear()
		g.update(1.0 / 60.0, clamp((mid - g.player_x) / 10.0, -1.0, 1.0))
		t += 1.0 / 60.0
	_check(g.state == Logic.State.PLAY, "autopilot survives 20 s of canyon (dist=%.0f)" % g.dist)
	_check(g.score >= int(g.dist / 10.0) and g.score > 0, "score tracks distance (%d)" % g.score)

	# Steer hard into the left wall: crash.
	t = 0.0
	while t < 5.0 and g.state == Logic.State.PLAY:
		g.update(1.0 / 60.0, -1.0)
		t += 1.0 / 60.0
	_check(g.state == Logic.State.CRASHED, "hitting the canyon wall crashes")
	var crashed_score: int = g.score
	_check(not g.restart_if_ready(), "restart ignored during crash hold")
	g.update(Logic.CRASH_HOLD + 0.1)
	_check(g.restart_if_ready(), "restart accepted after the hold")
	_check(g.state == Logic.State.READY and g.dist == 0.0 and g.score == 0, "reset back to the start")
	_check(g.best >= crashed_score, "best score kept across resets")

	# Bullets destroy a drifter placed straight ahead.
	g.start()
	g.enemies = [{"pos": Vector2(g.player_x, g.player_world_y() + 60.0), "vx": 0.0}]
	g.fire()
	_check(g.bullets.size() == 1, "fire spawns a bullet")
	for i in 30:
		g.update(1.0 / 60.0)
	_check(g.kills == 1 and g.enemies.is_empty(), "bullet destroys the drifter")

	# Ramming a drifter crashes.
	g.enemies = [{"pos": Vector2(g.player_x, g.player_world_y() + 4.0), "vx": 0.0}]
	g.update(1.0 / 60.0)
	_check(g.state == Logic.State.CRASHED, "ramming a drifter crashes")


func _scene_checks() -> void:
	var packed: PackedScene = load(SCENE)
	_check(packed != null, "loads game.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var g = scene.logic
	_check(g != null and g.state == Logic.State.READY, "scene owns a logic instance on the ready screen")
	g.start()
	var x0: float = g.player_x
	var d0: float = g.dist
	scene.steer_override = -1.0
	for i in 10:
		await process_frame
	scene.steer_override = 0.0
	_check(g.player_x < x0, "scene steers the craft (dx=%.1f)" % (g.player_x - x0))
	_check(g.dist > d0, "scene scrolls the canyon")
	_check(scene.get_node("%BackButton") is Button, "Back to Arcade button present")
	scene.queue_free()
	await process_frame
