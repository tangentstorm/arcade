extends SceneTree
## Headless logic checks for the doth direct port.
## Run: godot --headless --path . --script res://tools/test_doth.gd

const World := preload("res://games/doth/direct/doth_world.gd")
const Levels := preload("res://games/doth/direct/doth_levels.gd")
const Tiles := preload("res://games/doth/direct/doth_tiles.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: doth ", msg)
		_fail += 1


func _initialize() -> void:
	_check(Levels.OVERWORLD.size() == 20, "overworld has 20 rows")
	_check(Levels.OVERWORLD[0].length() == 70, "overworld row width 70")
	_check(Levels.STARTER.size() == 20 and Levels.STARTER[0].length() == 70, "starter 70x20")

	var w = World.new()
	_check(w.state == World.State.TITLE, "starts on title")
	_check(w.cells.size() == 70 * 20, "cell buffer sized")

	w.start_play("starter")
	_check(w.state == World.State.PLAY, "enter play")
	_check(w.get_cell(w.hero) == World.Kind.HERO, "hero on map")
	_check(w.health == World.HP_START, "hpstart=%d" % World.HP_START)

	# Walls block.
	var blocked := w.try_move(0, -1)  # toward top border from (20,10) may hit wall above chamber
	# Move around inside chamber toward a known coin at (15,8) from (20,10).
	w.load_level("starter")
	w.state = World.State.PLAY
	# Force hero next to a coin.
	w.set_cell(w.hero, World.Kind.FLOOR)
	w.hero = Vector2i(14, 8)
	w.set_cell(w.hero, World.Kind.HERO)
	_check(w.get_cell(Vector2i(15, 8)) == World.Kind.COIN, "coin at (15,8)")
	var cash0: int = w.cash
	_check(w.try_move(1, 0), "walk onto coin")
	_check(w.cash == cash0 + 1, "coin awards cash")
	_check(w.get_cell(w.hero) == World.Kind.HERO, "hero moved")

	# Wall collision
	w.set_cell(w.hero, World.Kind.FLOOR)
	w.hero = Vector2i(1, 1)
	w.set_cell(w.hero, World.Kind.HERO)
	# (0,1) is wall (border)
	_check(not w.try_move(-1, 0), "wall blocks west")

	# Boulder push
	w.start_play("starter")
	w.set_cell(w.hero, World.Kind.FLOOR)
	w.hero = Vector2i(39, 10)
	w.set_cell(w.hero, World.Kind.HERO)
	_check(w.get_cell(Vector2i(40, 10)) == World.Kind.BOULDER, "boulder at (40,10)")
	# Clear beyond if needed — (41,10) is also boulder in starter; push chain may fail.
	# Place a lone boulder with empty beyond.
	w.set_cell(Vector2i(40, 10), World.Kind.FLOOR)
	w.set_cell(Vector2i(41, 10), World.Kind.FLOOR)
	w.set_cell(Vector2i(42, 10), World.Kind.FLOOR)
	w.set_cell(Vector2i(42, 11), World.Kind.FLOOR)
	w.set_cell(Vector2i(40, 10), World.Kind.BOULDER)
	_check(w.try_move(1, 0), "push boulder")
	_check(w.get_cell(Vector2i(41, 10)) == World.Kind.BOULDER, "boulder moved east")
	_check(w.hero == Vector2i(40, 10), "hero followed push")

	# Overworld loads from dmap1 decode
	w.start_play("overworld")
	_check(w.level_id == "overworld", "overworld id")
	var walls := 0
	for i in w.cells.size():
		if w.cells[i] == World.Kind.WALL:
			walls += 1
	_check(walls > 200, "overworld has many walls (%d)" % walls)

	# Atlas builds
	var tex := Tiles.build_atlas()
	_check(tex != null and tex.get_width() == Tiles.COLS * Tiles.TILE, "atlas width")

	# Title key
	w.reset_title()
	w.handle_title_key(KEY_1)
	_check(w.state == World.State.PLAY and w.level_id == "starter", "title 1 → starter")

	if _fail == 0:
		print("test_doth: OK")
		quit(0)
	else:
		print("test_doth: FAIL ", _fail)
		quit(1)
