extends SceneTree
## Headless logic checks for the sketchbots direct port.
## Run: godot --headless --path . --script res://tools/test_sketchbots.gd

const L := preload("res://games/sketchbots/direct/sketchbots_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: sketchbots ", msg)
		_fail += 1


func _initialize() -> void:
	var w = L.new()
	_check(w.orange_x == 125 and w.orange_y == 125, "starts centred facing left (%d,%d)" % [w.orange_x, w.orange_y])
	_check(w.orange_face == L.Face.L, "starts facing left")
	_check(w.blue_x() == 125 and w.blue_y() == 250, "blue guy at bottom centre")

	# East: face + 10 px/frame
	w.handle_key("d", true)
	_check(w.orange_face == L.Face.R and w.heading == L.EAST, "d sets east + face right")
	w.step()
	_check(w.orange_x == 135 and w.orange_y == 125, "east moves 10px (%d,%d)" % [w.orange_x, w.orange_y])
	w.handle_key("d", false)

	# Diagonal: full speed both axes
	w.handle_key("w", true)
	w.handle_key("d", true)
	_check(w.heading == (L.NORTH | L.EAST) and w.orange_face == L.Face.R, "w then d: NE, face from last press")
	var x0: int = w.orange_x
	var y0: int = w.orange_y
	w.step()
	_check(w.orange_x == x0 + 10 and w.orange_y == y0 - 10, "diagonal is 10,10 not normalised")
	w.handle_key("w", false)
	w.handle_key("d", false)

	# Opposing bits: no match in switch → stand still
	w.handle_key("w", true)
	w.handle_key("s", true)
	x0 = w.orange_x
	y0 = w.orange_y
	w.step()
	_check(w.orange_x == x0 and w.orange_y == y0, "north|south cancels movement")
	w.handle_key("w", false)
	w.handle_key("s", false)

	# Arrow-Up sets heading but not face
	w.orange_face = L.Face.R
	w.handle_key("up", true)
	_check(w.heading & L.NORTH != 0 and w.orange_face == L.Face.R, "up sets north without changing face")
	w.handle_key("up", false)

	# Bottom clamp only
	w.heading = 0
	w.orange_x = 125
	w.orange_y = 260
	w.handle_key("s", true)
	w.step()
	_check(w.orange_y == 250, "bottom clamp (%d)" % w.orange_y)
	w.handle_key("s", false)

	# Top is not clamped
	w.orange_y = 5
	w.handle_key("w", true)
	w.step()
	_check(w.orange_y == -5, "top not clamped (%d)" % w.orange_y)
	w.handle_key("w", false)

	# XOR release quirk: release without press flips the bit on
	w.heading = 0
	w.handle_key("a", false)
	_check(w.heading == L.WEST, "xor release without press sets west")

	if _fail == 0:
		print("test_sketchbots: OK")
		quit(0)
	else:
		print("test_sketchbots: FAILED (%d)" % _fail)
		quit(1)
