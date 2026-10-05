extends SceneTree
## Headless logic checks for the toroidal_zombie_herder direct port.
## Run: godot --headless --path . --script res://tools/test_toroidal_zombie_herder.gd

const World := preload("res://games/toroidal_zombie_herder/direct/tzh_world.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: toroidal_zombie_herder ", msg)
		_fail += 1


func _initialize() -> void:
	var w = World.new()
	_check(w.instances.size() == 651, "room0 has 651 instances (%d)" % w.instances.size())
	_check(w.of_kind(World.ZOMBIE).size() == 6 and w.of_kind(World.TRAP).size() == 6,
		"6 zombies, 6 traps")
	_check(w.hero.x == 320 and w.hero.y == 256, "hero starts at (320,256)")
	_check(w.place_free(w.hero, w.hero.x, w.hero.y), "hero start is free")

	# Hero moves 8px/step along the corridor and stays grid-snapped on the other axis.
	var start_x: float = w.hero.x
	w.step({"right": true})
	_check(w.hero.x == start_x + 8 and w.hero.y == 256, "right arrow moves 8px (%s)" % w.hero.x)
	# Releasing snaps back to the 32px grid.
	w.step({})
	_check(fmod(w.hero.x, 32.0) == 0.0, "released hero snaps to grid (%s)" % w.hero.x)

	# Walls block: (320,224) is a wall directly above the start. As in GM, the
	# while-loop in MoveHero lets the hero nudge 4px into the mask slack, no further.
	var w2 = World.new()
	for i in 5:
		w2.step({"up": true})
	_check(w2.hero.y == 252, "wall above blocks upward move (%s)" % w2.hero.y)

	# Coin pickup: the hero starts on top of no coin; walking left across coins scores.
	var w3 = World.new()
	for i in 8:
		w3.step({"left": true})
	_check(w3.score > 0, "walking left collects coins (score %d)" % w3.score)

	# Zombies chase (potential_step speed 2).
	var w4 = World.new()
	var z = w4.of_kind(World.ZOMBIE)[0]
	var d0 := Vector2(z.x, z.y).distance_to(Vector2(w4.hero.x, w4.hero.y))
	for i in 30:
		w4.step({})
	var d1 := Vector2(z.x, z.y).distance_to(Vector2(w4.hero.x, w4.hero.y))
	_check(d1 < d0, "zombie approaches hero (%.1f -> %.1f)" % [d0, d1])

	# Standing still long enough: a zombie reaches the hero -> room restarts, score kept.
	var w5 = World.new()
	w5.score = 30
	var n := 0
	while w5.restarts == 0 and n < 3000:
		w5.step({}); n += 1
	_check(w5.restarts == 1, "zombie catches idle hero -> room_restart (step %d)" % n)
	_check(w5.score == 30, "score survives room_restart (GM global)")
	_check(w5.of_kind(World.ZOMBIE).size() == 6, "restart respawns zombies")

	# Trap: zombie touching trap destroys both.
	var w6 = World.new()
	var zz = w6.of_kind(World.ZOMBIE)[0]
	var tt = w6.of_kind(World.TRAP)[0]
	zz.x = tt.x; zz.y = tt.y
	w6.step({})
	_check(w6.of_kind(World.ZOMBIE).size() == 5 and w6.of_kind(World.TRAP).size() == 5,
		"zombie + trap destroy each other")

	# Toroidal wrap: row 3 (y=96) is open at both edges; walking left wraps right.
	var w7 = World.new()
	w7.hero.x = 0; w7.hero.y = 96
	_check(w7.place_free(w7.hero, 0, 96), "edge cell (0,96) is free")
	w7.step({"left": true})
	_check(w7.hero.x > 1000, "hero wraps from left edge to right (%s)" % w7.hero.x)

	print("toroidal_zombie_herder tests: %s" % ("PASS" if _fail == 0 else "%d FAIL" % _fail))
	quit(1 if _fail else 0)
