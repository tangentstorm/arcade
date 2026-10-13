extends SceneTree
## Headless logic checks for tankgame Direct.
## Run: godot --headless --path . --script res://tools/test_tankgame.gd

const L := preload("res://games/tankgame/direct/tank_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: tankgame ", msg)
		_fail += 1


func _initialize() -> void:
	var g = L.new()
	g.generate(42)
	_check(g.grid.size() == (L.MW + 1) * (L.MH + 1), "grid is 81x61")
	# Each column is a single air->sand step that moves at most 1 per column.
	var ok_cols := true
	var prev := -1
	for x in L.MW + 1:
		var lvl := 0
		while lvl <= L.MH and g.get_bit(x, lvl) == 0:
			lvl += 1
		for y in range(lvl, L.MH + 1):
			if g.get_bit(x, y) != 1:
				ok_cols = false
		if prev >= 0 and absi(lvl - prev) > 1:
			ok_cols = false
		prev = lvl
	_check(ok_cols, "random walk columns are monotone, step <= 1")
	var bad := false
	for x in L.MW:
		for y in L.MH:
			var t: int = g.msquare(x, y)
			if t < 0 or t > 15:
				bad = true
	_check(not bad, "msquare in 0..15")
	_check(g.msquare(0, 0) == 0 and g.msquare(0, L.MH - 1) == 15, "sky=0, deep sand=15")
	var h = L.new()
	h.generate(42)
	_check(h.grid == g.grid, "same seed -> same terrain")
	h.generate(7)
	_check(h.grid != g.grid, "new seed -> new terrain")
	_check(L.tank_pos(1) == Vector2(400, 300) and L.gun_pos(0) == Vector2(225, 303),
		"original tank/gun positions")
	var scene: PackedScene = load("res://games/tankgame/direct/game.tscn")
	_check(scene != null and scene.can_instantiate(), "direct scene loads")
	print("VERIFY DONE: ", _fail)
	quit(_fail)
