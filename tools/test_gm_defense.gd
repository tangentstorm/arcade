extends SceneTree
## Headless logic checks for the gm_defense direct port.
## Run: godot --headless --path . --script res://tools/test_gm_defense.gd

const World := preload("res://games/gm_defense/direct/gmd_world.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: gm_defense ", msg)
		_fail += 1


func _initialize() -> void:
	var w = World.new()
	_check(w.ship.x == 320 and w.ship.y == 416, "ship starts at (320,416)")
	_check(w.squid.x == 352 and w.squid.y == 288, "squid at (352,288)")

	# Create: speed=5, direction 0 -> flies right immediately.
	w.step()
	_check(is_equal_approx(w.ship.x, 325.0) and is_equal_approx(w.ship.y, 416.0),
		"ship moves right 5px/step (%s,%s)" % [w.ship.x, w.ship.y])

	# Key Press Left: direction 180, sprite flipped.
	w.step({"left_pressed": true})
	_check(is_equal_approx(w.ship.x, 320.0) and w.ship.image_xscale == -1,
		"left press reverses + flips (%s, xscale %s)" % [w.ship.x, w.ship.image_xscale])
	_check(is_equal_approx(w.ship.y, 416.0), "ship stays on its row (%s)" % w.ship.y)
	w.step()
	_check(is_equal_approx(w.ship.x, 315.0), "keeps flying left without key held (%s)" % w.ship.x)

	# Key Press Right: back to direction 0.
	w.step({"right_pressed": true})
	_check(is_equal_approx(w.ship.x, 320.0) and w.ship.image_xscale == 1,
		"right press turns back (%s)" % w.ship.x)

	# No Outside Room event: the ship leaves the room and keeps going.
	var w2 = World.new()
	for i in 200:
		w2.step()
	_check(w2.ship.x > World.W + 25 and not w2.ship_on_screen(),
		"ship flies off the right edge (%s)" % w2.ship.x)
	for i in 200:
		w2.step({"left_pressed": i == 0})
	_check(w2.ship_on_screen(), "pressing left brings it back (%s)" % w2.ship.x)

	# Squid never moves; s_squid animates 4 frames at 5 fps (12 steps per frame at 60).
	var w3 = World.new()
	for i in 12:
		w3.step()
	_check(int(w3.squid.image_index) == 1, "squid frame 1 after 0.2s (%s)" % w3.squid.image_index)
	for i in 36:
		w3.step()
	_check(int(round(w3.squid.image_index)) % 4 == 0, "squid loops after 4 frames (%s)" % w3.squid.image_index)
	_check(w3.squid.x == 352 and w3.squid.y == 288, "squid stays put")

	# Scene loads and builds its room.
	var packed := load("res://games/gm_defense/direct/game.tscn") as PackedScene
	_check(packed != null, "game.tscn loads")
	if packed:
		var inst := packed.instantiate()
		root.add_child(inst)
		_check(inst.get_node_or_null("%Room") != null and inst.has_method("_draw_room"), "scene has Room canvas + script")
		inst.queue_free()

	print("gm_defense: %s" % ("OK" if _fail == 0 else "%d FAIL" % _fail))
	quit(1 if _fail else 0)
