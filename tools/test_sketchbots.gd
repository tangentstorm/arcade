extends SceneTree
## Headless logic checks for the sketchbots direct port (two-player).
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
	_check(w.blue_x == 125 and w.blue_y == 250, "blue guy at bottom centre")
	_check(w.blue_face == L.Face.D, "blue starts facing down")

	# East: face + 10 px/frame (orange / WASD)
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

	# Arrow keys move blue (not orange); face updates
	var ox: int = w.orange_x
	var oy: int = w.orange_y
	var of: int = w.orange_face
	w.handle_key("up", true)
	_check(w.blue_heading & L.NORTH != 0 and w.blue_face == L.Face.U, "up sets blue north + face U")
	_check(w.heading == 0 and w.orange_face == of, "up does not affect orange")
	var bx0: int = w.blue_x
	var by0: int = w.blue_y
	w.step()
	_check(w.blue_x == bx0 and w.blue_y == by0 - 10, "blue north moves 10px")
	_check(w.orange_x == ox and w.orange_y == oy, "orange stays put while blue moves")
	w.handle_key("up", false)

	w.handle_key("right", true)
	_check(w.blue_face == L.Face.R and w.blue_heading == L.EAST, "right sets blue east + face R")
	bx0 = w.blue_x
	by0 = w.blue_y
	w.step()
	_check(w.blue_x == bx0 + 10 and w.blue_y == by0, "blue east moves 10px")
	w.handle_key("right", false)

	w.handle_key("left", true)
	_check(w.blue_face == L.Face.L, "left sets blue face L")
	w.handle_key("left", false)
	w.handle_key("down", true)
	_check(w.blue_face == L.Face.D and w.blue_heading == L.SOUTH, "down sets blue south + face D")
	w.handle_key("down", false)

	# Bottom clamp only (orange)
	w.heading = 0
	w.orange_x = 125
	w.orange_y = 260
	w.handle_key("s", true)
	w.step()
	_check(w.orange_y == 250, "bottom clamp (%d)" % w.orange_y)
	w.handle_key("s", false)

	# Bottom clamp (blue)
	w.blue_heading = 0
	w.blue_x = 125
	w.blue_y = 260
	w.handle_key("down", true)
	w.step()
	_check(w.blue_y == 250, "blue bottom clamp (%d)" % w.blue_y)
	w.handle_key("down", false)

	# Top is not clamped
	w.orange_y = 5
	w.handle_key("w", true)
	w.step()
	_check(w.orange_y == -5, "top not clamped (%d)" % w.orange_y)
	w.handle_key("w", false)

	# XOR release quirk: release without press flips the bit on (per player)
	w.heading = 0
	w.handle_key("a", false)
	_check(w.heading == L.WEST, "xor release without press sets west (orange)")
	w.blue_heading = 0
	w.handle_key("left", false)
	_check(w.blue_heading == L.WEST, "xor release without press sets west (blue)")

	if _fail == 0:
		print("test_sketchbots: OK")
		quit(0)
	else:
		print("test_sketchbots: FAILED (%d)" % _fail)
		quit(1)
