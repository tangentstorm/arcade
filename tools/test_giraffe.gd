extends SceneTree
## Headless logic checks for the giraffe direct port.
## Run: godot --headless --path . --script res://tools/test_giraffe.gd

const Logic := preload("res://games/giraffe/direct/giraffe_logic.gd")
const MapData := preload("res://games/giraffe/direct/map_data.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: giraffe ", msg)
	else:
		print("SMOKE FAIL: giraffe ", msg)
		_fail += 1


func _initialize() -> void:
	# Map fidelity: platforms at cart positions; tile 16 is ground, 17 décor.
	_check(MapData.mget(2, 4) == 16 and MapData.mget(0, 5) == 16, "platform tiles from __map__")
	_check(MapData.mget(0, 8) == 17 and MapData.mget(15, 8) == 17, "bottom décor row is tile 17")
	_check(MapData.mget(2, 5) == 0, "empty cell under a platform")

	var g = Logic.new()
	_check(is_equal_approx(g.hx, Logic.OX) and is_equal_approx(g.hy, 16.0), "starts at ox,16")

	# Fall onto the platform under the spawn (map cell (0,5)=16 → top y=40).
	# Hero at hy=16 → my=2; need to fall until standing on a ground cell.
	for i in 60:
		g.step({})
	_check(g.on_ground and is_equal_approx(g.dy, 0.0), "lands on ground tile 16")
	_check(is_equal_approx(g.hy, float(g.my * Logic.CELL)), "snaps hy to cell top")

	# Jump while grounded: dy = -6 for one frame of held jump on landing frame...
	# After landing with no jump, step with jump held.
	var hy0: float = g.hy
	g.step({"jump": true})
	_check(g.dy < 0.0 and g.hy < hy0, "jump lifts the hero (dy starts -6)")

	# Hold nothing: fall past y=128 and reset.
	g.hx = Logic.OX
	g.hy = 120.0
	g.dx = 0.0
	g.dy = 5.0
	for i in 20:
		g.step({})
		if is_equal_approx(g.hy, 16.0) and is_equal_approx(g.hx, Logic.OX):
			break
	_check(is_equal_approx(g.hy, 16.0) and is_equal_approx(g.dx, 0.0), "hy>128 resets to spawn")

	# Walk accel / flip
	g = Logic.new()
	# Place on ground artificially
	g.hx = 8.0
	g.hy = 32.0  # my=4; cell below (1,5) may be empty — force ground path
	# Walk right in air then check dx friction path
	g.step({"right": true})
	_check(g.dx > 0.0, "right accel")
	g.step({"left": true})
	# after left while dx was positive, still may be positive; keep lefting
	for i in 10:
		g.step({"left": true})
	_check(g.dx < 0.0 and g.flip_x, "left facing flips sprite")

	quit(1 if _fail else 0)
