extends SceneTree
## Headless checks for mineswpr Enhanced (presentation over the Direct logic + shell).
## Run: godot --headless --path . --script res://tools/test_mineswpr_enhanced.gd

const Logic := preload("res://games/mineswpr/direct/mineswpr_logic.gd")
const Shell := preload("res://games/mineswpr/direct/mswp_shell.gd")
const SCENE := "res://games/mineswpr/enhanced/game.tscn"
const TEST_SAVE := "user://mineswpr_enhanced_test.cfg"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: mineswpr_enhanced ", msg)
	else:
		print("SMOKE FAIL: mineswpr_enhanced ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, unicode := 0, shift := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.shift_pressed = shift
	ev.pressed = true
	return ev


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	_test_parity_vs_direct()
	await _test_scene()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("mineswpr_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


## A scripted session of clicks through Enhanced must leave the exact same
## board, flags, stack and game-over state as the same commands run on Direct.
func _test_parity_vs_direct() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	var mines := [Logic.cell(1, 0), Logic.cell(0, 1), Logic.cell(5, 5), Logic.cell(9, 3),
		Logic.cell(12, 12), Logic.cell(3, 14)]
	var d = Logic.new(42)
	var ds = Shell.new(d)
	d.load_mines(mines)
	inst.game.load_mines(mines)
	_check(inst.game.get_script() == Logic and inst.shell.get_script() == Shell,
		"uses the Direct logic and shell scripts (no rules copy)")
	# [x, y, button] clicks; Direct gets the same command its own click handler runs
	var moves := [[10, 10, MOUSE_BUTTON_LEFT], [0, 5, MOUSE_BUTTON_RIGHT], [0, 0, MOUSE_BUTTON_RIGHT],
		[0, 0, MOUSE_BUTTON_RIGHT], [1, 1, MOUSE_BUTTON_LEFT], [12, 11, MOUSE_BUTTON_LEFT],
		[9, 3, MOUSE_BUTTON_RIGHT], [15, 0, MOUSE_BUTTON_LEFT]]
	var same := true
	for m in moves:
		var op := "?"
		if m[2] == MOUSE_BUTTON_RIGHT:
			op = "-" if d.has(Logic.cell(m[0], m[1]), Logic.FLAG) else "+"
		ds.eval_line("%X %X %s" % [m[0], m[1], op])
		d.active_cell = -1
		inst.click_cell(m[0], m[1], m[2])
		same = same and d.grid == inst.game.grid and d.flag_count == inst.game.flag_count
	_check(same, "board + flags identical to Direct after every click (%d moves)" % moves.size())
	_check(inst.game.has(Logic.cell(0, 0), Logic.COVER), "(0,0) behind the cardinal mine wall stays covered, as in Direct")
	# typed commands go through the same shell: persistent hex stack
	ds.eval_line("3"); ds.eval_line("4 ?")
	inst.run("3"); inst.run("4 ?")
	_check(d.grid == inst.game.grid and ds.stack == inst.shell.stack, "typed '3' then '4 ?' matches Direct (stack persists)")
	ds.eval_line("5 5 ?")
	inst.click_cell(5, 5, MOUSE_BUTTON_LEFT)
	_check(d.game_over and inst.game.game_over and d.grid == inst.game.grid, "hitting a mine: same game over as Direct")
	_check(inst.state == inst.LOST and inst._cards["result"].visible, "loss shows the BOOM card")
	_check(inst._particles.size() > 30 and inst._shake > 0.0, "loss juice: explosion particles + shake")
	var g_before: PackedInt32Array = inst.game.grid.duplicate()
	inst.click_cell(7, 7, MOUSE_BUTTON_LEFT)
	_check(inst.game.grid == g_before, "board clicks are ignored while the result card is up")
	inst.free()


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("mineswpr", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("mineswpr", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	inst.save_path = TEST_SAVE
	inst.best_time = -1.0
	_check(inst.game.covered_count() == 256 and inst.mines_left() == 24, "fresh 16x16 board, 24 mines left")

	var back: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			back = b
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")

	# keyboard: arrows move the cursor, Tab flags, Enter reveals
	inst.game.load_mines([Logic.cell(15, 15)])
	inst.cursor = Vector2i(0, 0)
	root.push_input(_key(KEY_RIGHT))
	root.push_input(_key(KEY_DOWN))
	await _frames(1)
	_check(inst.cursor == Vector2i(1, 1), "arrows move the cursor")
	root.push_input(_key(KEY_TAB))
	await _frames(1)
	_check(inst.game.has(Logic.cell(1, 1), Logic.FLAG) and inst.mines_left() == 23 and inst._flag_at.has(Logic.cell(1, 1)),
		"Tab flags the cursor cell (counter 23, flag pops in)")
	root.push_input(_key(KEY_TAB))
	await _frames(1)
	_check(not inst.game.has(Logic.cell(1, 1), Logic.FLAG), "Tab again unflags")
	inst.cursor = Vector2i(14, 15)
	root.push_input(_key(KEY_ENTER))
	await _frames(1)
	_check(not inst.game.has(Logic.cell(14, 15), Logic.COVER) and inst.game.covered_count() == 255,
		"Enter on an empty prompt reveals at the cursor (hint cell)")
	_check(inst.running, "timer starts on the first reveal")
	# typed command at the ok prompt (hex)
	for ch in "0 0 ?":
		root.push_input(_key(KEY_NONE if ch == " " else KEY_A, ch.unicode_at(0)))
	root.push_input(_key(KEY_ENTER))
	await _frames(2)
	_check(inst.last_cmd == "0 0 ?", "typed command echoed as last command")
	_check(inst.game.covered_count() == 1, "typed '0 0 ?' floods the board")
	_check(inst._reveal_at.size() >= 254, "flood queues a ripple reveal per opened cell")
	_check(inst.state == inst.WON and inst._cards["result"].visible, "clearing every safe cell shows ALL CLEAR")
	_check(inst.best_time >= 0.0 and inst._load_best() >= 0.0, "win saves a best time")
	_check(inst._particles.size() > 50, "win juice: confetti")
	_check(not inst.running, "timer stops on win")

	# new game resets the view
	inst.new_game()
	await _frames(1)
	_check(inst.state == inst.PLAY and not inst._cards["result"].visible and inst.game.covered_count() == 256
		and inst.elapsed == 0.0, "New Game resets board, card and timer")
	# flagging on a fresh board must not count as a new board
	inst.click_cell(3, 3, MOUSE_BUTTON_RIGHT)
	_check(inst._flag_at.has(Logic.cell(3, 3)), "flag on a fresh board keeps its animation state")

	# Esc -> PauseOverlay (tree pause), Esc again -> arcade
	var t0: float = inst.elapsed
	inst.running = true
	root.push_input(_key(KEY_ESCAPE))
	await _frames(8)
	_check(paused and is_equal_approx(inst.elapsed, t0), "Esc opens PauseOverlay and freezes the timer")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
