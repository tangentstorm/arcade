extends SceneTree
## Headless logic checks for the killem_all direct port.
## Run: godot --headless --path . --script res://tools/test_killem_all.gd

const World := preload("res://games/killem_all/direct/ka_world.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: killem_all ", msg)
		_fail += 1


func _initialize() -> void:
	var w = World.new()
	_check(w.ship_x == 512 and w.ship_y == 384, "init.gml centres the ship (%s,%s)" % [w.ship_x, w.ship_y])
	_check(w.blast_x == 480 and w.blast_y == 416, "blast starts at its room position")

	# point_direction: GM degrees, CCW, y down.
	_check(is_equal_approx(World.point_direction(0, 0, 10, 0), 0.0), "point_direction right = 0")
	_check(is_equal_approx(World.point_direction(0, 0, 0, -10), 90.0), "point_direction up = 90")
	_check(is_equal_approx(World.point_direction(0, 0, 0, 10), 270.0), "point_direction down = 270")

	# Thrust: +1 px/step^2 along the heading, clamped to 10 per axis.
	w.step({"right": true, "mouse": Vector2(1000, 384)})
	_check(is_equal_approx(w.dx, 1.0) and is_equal_approx(w.ship_x, 513.0), "right thrust accelerates (%s)" % w.dx)
	_check(w.blast_x == w.ship_x and w.blast_y == w.ship_y, "blast follows ship")
	for i in 30:
		w.step({"right": true, "mouse": Vector2(1000, 384)})
	_check(is_equal_approx(w.dx, 10.0), "dx clamps at MAXSPEED (%s)" % w.dx)

	# Diagonal heading uses arctan2: each axis gets cos/sin(45°).
	var w2 = World.new()
	w2.step({"up": true, "left": true})
	_check(is_equal_approx(w2.dx, -sqrt(0.5)) and is_equal_approx(w2.dy, -sqrt(0.5)),
		"diagonal thrust (%s,%s)" % [w2.dx, w2.dy])

	# Coasting: velocity *= 0.99 per step without keys.
	var dx0: float = w.dx
	w.step({"mouse": Vector2(1000, 384)})
	_check(is_equal_approx(w.dx, dx0 * 0.99), "coasting friction 0.99 (%s)" % w.dx)

	# Aim + fire: gun points at mouse; bullet spawns 30px out, moves 10px/step,
	# kickback pushes the ship away from the mouse.
	var w3 = World.new()
	w3.step({"fire": true, "mouse": Vector2(512, 100)})  # straight up
	_check(is_equal_approx(w3.blast_angle, 90.0), "gun aims at mouse (%s)" % w3.blast_angle)
	_check(w3.bullets.size() == 1, "holding the button fires a bullet")
	var b = w3.bullets[0]
	_check(is_equal_approx(b.x, 512.0) and is_equal_approx(b.y, 384.0 - 30.0 - 10.0),
		"bullet spawns at gun radius and moves the same step (%s,%s)" % [b.x, b.y])
	_check(is_equal_approx(w3.dy, 0.05) and absf(w3.dx) < 1e-9, "kickback away from aim (%s,%s)" % [w3.dx, w3.dy])
	w3.step({"fire": true, "mouse": Vector2(512, 100)})
	_check(w3.bullets.size() == 2 and w3.fired == 2, "fires every step while held")
	for i in 60:
		w3.step({"mouse": Vector2(512, 100)})
	_check(w3.bullets.size() == 0, "bullets past the room edge are culled")
	_check(w3.ship_y > 384.0, "recoil drifted the ship down (%s)" % w3.ship_y)

	# Room has no walls: the ship can leave (no Outside Room event).
	var w4 = World.new()
	for i in 120:
		w4.step({"left": true})
	_check(w4.ship_x < 0, "ship can fly out of the room (%s)" % w4.ship_x)

	var packed := load("res://games/killem_all/direct/game.tscn") as PackedScene
	_check(packed != null, "game.tscn loads")
	if packed:
		var inst := packed.instantiate()
		root.add_child(inst)
		_check(inst.get_node_or_null("%Room") != null and inst.has_method("_draw_room"), "scene has Room canvas + script")
		inst.queue_free()

	print("killem_all: %s" % ("OK" if _fail == 0 else "%d FAIL" % _fail))
	quit(1 if _fail else 0)
