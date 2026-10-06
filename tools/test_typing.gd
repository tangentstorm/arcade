extends SceneTree
## Headless logic checks for typing Direct.
## Run: godot --headless --path . --script res://tools/test_typing.gd

const L := preload("res://games/typing/direct/typing_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: typing ", msg)
		_fail += 1


func _initialize() -> void:
	var g = L.new()
	g.start_play()
	_check(g.word == "go" and g.score == 0 and g.speed == 0, "start go score0 speed0")
	g.type_key("g")
	_check(g.progress == 1, "typed g")
	g.type_key("x")
	_check(g.progress == 1 and g.flash_kind == "nope", "wrong key flashes nope")
	g.flash_ttl = 0.0
	g.flash_kind = ""
	g.type_key("o")
	_check(g.score == 1 and g.falling, "typed go -> score 1, falling")
	# Drain new-word delay
	g.tick(0.25)
	_check(g.word != "go" or g.progress == 0, "new word after delay")

	# Fail at bottom
	g.force_word("ab", 100.0, L.BOTTOM_Y)
	g.falling = true
	g.speed = 1
	g.tick(0.2)
	_check(g.flash_kind == "fail", "fail at bottom")

	# Win at 15
	var w = L.new()
	w.start_play()
	w.score = 14
	w.falling = true
	w.force_word("a", 100.0, 10.0)
	w.type_key("a")
	_check(w.mode == L.Mode.WON and w.score == 15, "win at 15")

	if _fail == 0:
		print("VERIFY DONE: 0")
	else:
		print("VERIFY DONE: ", _fail)
	quit(_fail)
