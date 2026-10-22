extends SceneTree
## Headless rule checks for Squirrel Command Direct (1:1 with the artifact JS).
## Run: godot --headless --path . --script res://tools/test_squirrel_command.gd

const L := preload("res://games/squirrel_command/direct/squirrel_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: squirrel_command ", msg)
		_fail += 1


func _new() -> L:
	var g := L.new()
	g.rng.seed = 42
	g.reset()
	return g


func _initialize() -> void:
	var g := _new()
	_check(g.crops.size() == 5 and g.crops[2].x == 340.0 and g.crops[0].y == 402.0, "5 crops at xs 90..590, y=H-38")
	var mok := g.mounds.size() == 6
	for i in g.mounds.size():
		var m: Dictionary = g.mounds[i]
		mok = mok and m.x >= 60 + i * 112 and m.x <= 100 + i * 112 and m.y >= 26 and m.y <= 34
	_check(mok, "6 mounds at 60+i*112+[0,40), y 26..34")
	_check(g.to_spawn == 8 and is_equal_approx(g.spawn_t, 0.6) and g.wave_msg == 2.0, "wave 1: 5+3 squirrels, first after 0.6s")

	_check(L.boom_radius(0.125) == 22.0 and L.boom_radius(0.4) == 44.0
		and is_equal_approx(L.boom_radius(0.775), 22.0) and L.boom_radius(1.0) == 0.0, "boom radius grow/hold/shrink 44")

	g.fire(340, 200)
	g.fire(100, 100)
	_check(g.shots.size() == 1 and g.cool == 0.35, "0.35s cooldown blocks a 2nd shot")
	var sh: Dictionary = g.shots[0]
	g.step(0.05)
	_check(is_equal_approx(sh.y, 426.0 - 21.5), "shot flies 430 px/s from (W/2, H-14)")
	for i in 30:
		g.step(0.05)
	_check(g.shots.is_empty() and g.booms.size() <= 1, "shot reaches target and becomes a boom")

	g = _new()
	g.squirrels = [{"x": 300.0, "y": 200.0, "tx": 340.0, "target": g.crops[2], "sp": 0.0, "runner": false, "ph": 0.0, "leg": 0.0, "dead": false},
		{"x": 320.0, "y": 200.0, "tx": 340.0, "target": g.crops[2], "sp": 0.0, "runner": true, "ph": 0.0, "leg": 0.0, "dead": false}]
	g.to_spawn = 3
	g.booms = [{"x": 310.0, "y": 200.0, "t": 0.3, "r": 44.0}]
	g.step(0.01)
	_check(g.score == 35 and g.squirrels.is_empty() and g.pops.size() == 2, "blast kills: normal 10 + runner 25")

	g = _new()
	g.to_spawn = 0
	g.squirrels = [{"x": 90.0, "y": 395.0, "tx": 90.0, "target": g.crops[0], "sp": 46.0, "runner": false, "ph": 0.0, "leg": 0.0, "dead": false}]
	g.step(0.01)
	_check(not g.crops[0].alive and g.pops[0].eat, "squirrel within 14px eats the crop (chomp!)")
	_check(g.wave == 2 and g.score == 4 * 25 and g.to_spawn == 11, "wave clear: +25 per crop left, wave 2 = 11 squirrels")

	for c in g.crops:
		c.alive = false
	g.step(0.01)
	_check(g.over, "no crops left -> game over")
	g.fire(10, 10)
	_check(not g.over and g.score == 0 and g.alive_crops().size() == 5, "click when over restarts")

	# spawn cadence and speeds are seeded-deterministic
	g = _new()
	var t := 0.0
	while g.squirrels.is_empty() and t < 2.0:
		g.step(0.016)
		t += 0.016
	var q: Dictionary = g.squirrels[0]
	_check(t >= 0.59 and t <= 0.63, "first squirrel spawns at ~0.6s")
	_check(q.sp == 53.0 or is_equal_approx(q.sp, 53.0 * 1.7), "wave 1 speed 46+7 (x1.7 runner)")

	# The scene takes a click on the field.
	var scene: PackedScene = load("res://games/squirrel_command/direct/game.tscn")
	_check(scene != null and scene.can_instantiate(), "direct scene loads")
	var inst: Control = scene.instantiate()
	root.add_child(inst)
	inst.queue_redraw()
	await process_frame
	await process_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = inst._origin + (Vector2(16, 62) + Vector2(340, 200)) * inst._scale
	inst._gui_input(ev)
	_check(inst.state.shots.size() == 1 and inst.state.shots[0].tx == 340.0, "click on field fires at canvas coords")
	inst.free()
	print("VERIFY DONE: ", _fail)
	quit(_fail)
