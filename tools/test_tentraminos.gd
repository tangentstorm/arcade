extends SceneTree
## Headless logic checks for the tentraminos direct port.
## Run: godot --headless --path . --script res://tools/test_tentraminos.gd

const Logic := preload("res://games/tentraminos/direct/tentraminos_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: tentraminos ", msg)
		_fail += 1


func _initialize() -> void:
	var g = Logic.new(1234)
	# NEWGAME -> CASCADE ... -> NEXTROUND -> PLAYING
	var steps := 0
	while g.next != Logic.PLAYING and steps < 50:
		g.tick(); steps += 1
	_check(g.next == Logic.PLAYING, "reaches PLAYING after first drop (%d ticks)" % steps)
	_check(g.clock == 10 * Logic.SECONDS, "round clock is 10s")
	var bottom := 0
	for x in Logic.GW:
		if g.matrix[Logic.GW * (Logic.GH - 1) + x] != 0: bottom += 1
	_check(bottom >= 7, "first row fell to the bottom (cursor may hold 2): %d" % bottom)

	# rotation round-trip
	g.cursor_x = 0; g.cursor_y = 7
	var before: PackedInt32Array = g.matrix.duplicate()
	g.code("("); g.code(")")
	_check(g.matrix == before, "rotate ( then ) is identity")
	g.code("("); g.code("("); g.code("("); g.code("(")
	_check(g.matrix == before, "rotate ( x4 is identity")

	# scoring: a lit group of 5 scores 10*2^(5-4)=20 and clears
	var h = Logic.new(1)
	h.matrix.fill(0)
	for x in 5:
		h.matrix[Logic.GW * 8 + x] = 3
	h.markshapes()
	_check(h.matrix[Logic.GW * 8] == 12, "group of 5 lights up (3 -> 12)")
	h.clearshapes()
	_check(h.score == 20 and h.matrix[Logic.GW * 8] == 0, "group of 5 scores 20 and clears (score=%d)" % h.score)

	# gravity respects the cursor holding tiles in the air
	var k = Logic.new(1)
	k.matrix.fill(0)
	k.cursor_x = 0; k.cursor_y = 0
	k.matrix[0] = 1
	k.matrix[5] = 2
	while k.run_gravity() > 0: pass
	_check(k.matrix[0] == 1, "cursor holds tile in the air")
	_check(k.matrix[Logic.GW * 8 + 5] == 2, "free tile falls to the bottom")

	# full game reaches THEEND with no input
	var e = Logic.new(42)
	var n := 0
	while e.next != Logic.THEEND and n < 100000:
		e.tick(); n += 1
	_check(e.next == Logic.THEEND and e.game_over, "idle game ends (%d ticks, score %d)" % [n, e.score])
	e.new_game()
	_check(e.next == Logic.NEWGAME and e.score == 0, "new_game resets")
	quit(1 if _fail else 0)
