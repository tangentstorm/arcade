extends SceneTree
## Headless checks for Terratri Enhanced (presentation over the Direct rules).
## Run: godot --headless --path . --script res://tools/test_terratri_enhanced.gd

const Game := preload("res://games/terratri/direct/terratri_game.gd")
const DIRECT_SHELL := "res://games/terratri/direct/game.gd"
const SCENE := "res://games/terratri/enhanced/game.tscn"
const GOLDEN := "res://tools/golden/terratri_playouts.json"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: terratri_enhanced ", msg)
	else:
		print("SMOKE FAIL: terratri_enhanced ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _tap(code: Key) -> void:
	root.push_input(_key(code))
	root.push_input(_key(code, false))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_test_ownership()
	await _test_golden_parity()
	await _test_juice()
	await _test_scene()
	print("terratri_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _spawn() -> Node:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	return inst


func _test_ownership() -> void:
	var inst = _spawn()
	_check(inst.game.get_script() == Game, "snapshot is the Direct terratri_game.gd (no rules copy)")
	_check(inst._keys == load(DIRECT_SHELL).KEYS and inst._keys.size() > 10, "keymap comes from Direct game.gd KEYS")
	var copied := false
	for f in ["game.gd", "board.gd", "sfx.gd"]:
		var src := FileAccess.get_file_as_string("res://games/terratri/enhanced/" + f)
		for needle in ["func valid_steps", "func apply_step", "func after(", "func banked_moves", "func is_turn_over"]:
			if src.contains(needle):
				copied = true
	_check(not copied, "enhanced/ defines no rules functions")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(not inst.play_step("N") and inst.game.steps == "", "illegal step rejected (Blue can't move on Red's turn)")
	inst.free()


## Every golden TS playout replayed through Enhanced.play_step must leave the same
## snapshot as a bare Direct twin at every step; win/fort juice follows the diffs.
func _test_golden_parity() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	var inst = _spawn()
	await process_frame
	inst.start()
	var total_steps := 0
	var bad := ""
	var forts_ok := true
	var caps := 0
	var wins_ok := true
	for gm in data.games:
		inst.restart()
		var twin: RefCounted = Game.new()
		for ch in String(gm.final).replace("|", ""):
			if not inst.play_step(ch):
				bad = "seed %s step %d '%s' refused" % [gm.seed, total_steps, ch]
				break
			twin = twin.apply_step(ch)
			total_steps += 1
			var a = inst.game
			if a.steps != twin.steps or a.board != twin.board or a.whose_turn != twin.whose_turn \
					or a.winner != twin.winner or a.red_banked != twin.red_banked or a.blue_banked != twin.blue_banked \
					or a.red_supply != twin.red_supply or a.blue_supply != twin.blue_supply \
					or a.valid_steps.keys() != twin.valid_steps.keys() or a.valid_steps.values() != twin.valid_steps.values() \
					or a.history != twin.history:
				bad = "seed %s diverged at step %d" % [gm.seed, total_steps]
				break
		if bad != "":
			break
		for s in ["r", "b"]:
			forts_ok = forts_ok and inst.forts_built[s] == inst.game.forts_on_board(s)
		caps += inst.captures.r + inst.captures.b
		wins_ok = wins_ok and inst.game.winner == gm.winner and inst.state == inst.OVER \
			and inst._cards["win"].visible and inst._win_title.text == "%s WINS" % inst.side_name(gm.winner).to_upper()
	_check(bad == "", "golden playouts: %d games, %d steps identical to Direct twin %s" % [data.games.size(), total_steps, bad])
	_check(forts_ok, "fort-rise juice fired once per fort built (counts match the board)")
	_check(caps > 0, "capture juice fired in the goldens (%d captures)" % caps)
	_check(wins_ok, "every golden ends on the win card with the right winner")
	_check(inst.particles.size() > 40, "win confetti spawned (%d particles)" % inst.particles.size())
	# undo out of a win returns to play
	inst.undo()
	_check(inst.state == inst.PLAY and not inst._cards["win"].visible and inst.game.winner == "",
		"Undo from the win card returns to play")
	inst.free()


func _test_juice() -> void:
	var inst = _spawn()
	await process_frame
	inst.start()
	_check(inst.state == inst.PLAY and not inst._cards["title"].visible, "start() leaves the title")
	_check(inst.banner_t < 1.0 and inst.banner_side == "r", "start shows Red's turn banner")
	_check(inst.land_count("r") == 1 and inst.land_count("b") == 1, "land counts start 1 / 1")
	var p0: int = inst.particles.size()
	_check(inst.play_step("n"), "Red n")
	var c2 := 3 * 5 + 2  # c2 = (2, 3)
	_check(inst._pawn_k.r == 0.0 and inst._pawn_to.r == Vector2(2, 3), "pawn hop animates toward c2")
	_check(inst.claim_t[c2] < 1.0 and inst.claim_from[c2] == "", "claim ripple on the newly claimed square")
	_check(inst.particles.size() > p0, "claim particles")
	_check(inst.land_count("r") == 2, "Red land 2 after stepping off c1")
	_check(inst._status.text.contains("action 2 of 2") and inst._status.text.contains("bank"),
		"status: action 2 of 2 · or bank it")
	_check(not inst._buttons["k"].disabled and not inst._buttons["x"].disabled, "Bank + End turn enabled on action 2")
	_check(inst.play_step("k"), "Red banks")
	var texts: Array = inst.floaters.map(func(f): return f.text)
	_check(texts.has("+1 BANKED") and inst.game.banked("r") == 1, "bank: +1 BANKED floater")
	_check(inst.game.whose_turn == "b" and inst.banner_side == "b" and inst.banner_t == 0.0, "turn passes -> Blue banner")
	_check(inst._side_ui["b"].chip.text.contains("TO MOVE") and inst._side_ui["r"].chip.text == "",
		"Blue card shows TO MOVE")
	# let animations settle
	for i in 100:
		inst._process(1.0 / 60.0)
	_check(inst.claim_t[c2] == 1.0 and inst._pawn_k.r == 1.0 and inst.banner_t == 1.0, "animations settle")
	_check(inst.pawn_draw_pos("r") == Vector2(2, 3) and inst.pawn_hop("r") == 0.0, "pawn rests on its cell")
	# undo snaps visuals back
	inst.undo()
	inst.undo()
	_check(inst.game.steps == "" and inst.pawn_draw_pos("r") == Vector2(2, 4), "Undo x2 -> start, pawn snapped home")
	_check(inst.claim_t[c2] == 1.0 and inst.particles.size() >= 0, "undo leaves no pending claim anim")
	inst.restart()
	_check(inst.game.steps == "" and inst.captures.r == 0 and inst.state == inst.PLAY, "restart clears state")
	# The original's dead end: Blue at c5 boxed in by Red forts b5/d5 and the Red pawn on c4.
	# (Game replays without validating, like the TS, so a hand-built line is fine here.)
	inst.game = Game.new("nnwnnfseenfsw|")
	inst._sync_visuals()
	inst._refresh()
	_check(inst.game.valid_steps.is_empty() and inst._cards["stuck"].visible and inst._status.text.contains("boxed in"),
		"boxed-in position shows the BOXED IN card")
	inst.undo()
	_check(not inst._cards["stuck"].visible and not inst.game.valid_steps.is_empty(), "Undo leaves the boxed-in card")
	inst.free()


func _cell_pos(inst, cell: Vector2i) -> Vector2:
	return inst.board.get_global_transform_with_canvas() * inst.Board.cell_center(cell)


func _click(pos: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	root.push_input(mv, true)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	ev.global_position = pos
	ev.pressed = true
	root.push_input(ev, true)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up, true)


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("terratri", "enhanced")
	_check(entry != null and entry.is_playable(), "registry: enhanced playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(entry.scale_mode == "expand", "scale mode expand (title policy shared with Direct)")
	_check(reg.get_entry("terratri", "direct").is_playable(), "registry: direct still playable")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	var vp: Vector2 = inst.get_viewport_rect().size
	var fit: Vector2 = inst.STAGE * inst._stage.scale.x
	_check(fit.x <= vp.x + 0.5 and fit.y <= vp.y + 0.5 and (absf(fit.x - vp.x) < 1.0 or absf(fit.y - vp.y) < 1.0),
		"1280x720 stage fits the window (scale %.2f)" % inst._stage.scale.x)
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_tap(KEY_UP)
	await _frames(2)
	_check(inst.game.steps == "", "keys don't play steps on the title")
	var back: Button = null
	for b in inst.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade" and b.get_parent() == inst._stage:
			back = b
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")

	_tap(KEY_SPACE)
	await _frames(3)
	_check(inst.state == inst.PLAY and not inst._cards["title"].visible, "Space leaves title for play")
	_tap(KEY_UP)
	await _frames(2)
	_check(inst.game.steps == "n", "Up arrow plays Direct keymap step n")
	_click(_cell_pos(inst, Vector2i(1, 3)))
	await _frames(2)
	_check(inst.game.steps == "nw|", "click on b2 plays step w (turn ends)")
	_click(_cell_pos(inst, Vector2i(4, 4)))
	await _frames(2)
	_check(inst.game.steps == "nw|", "click on a non-target square is ignored")
	_tap(KEY_BACKSPACE)
	await _frames(2)
	_check(inst.game.steps == "n", "Backspace undoes one step")
	_tap(KEY_K)
	await _frames(2)
	_check(inst.game.steps == "nk|", "K banks")
	await _frames(10)
	_check(inst.time > 0.0, "process loop runs")

	# Esc -> PauseOverlay (tree pause freezes the shell), Esc again -> arcade
	_tap(KEY_ESCAPE)
	await _frames(4)
	var t0: float = inst.time
	await _frames(6)
	_check(paused and is_equal_approx(inst.time, t0), "Esc opens PauseOverlay and freezes the shell")
	_tap(KEY_ESCAPE)
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
