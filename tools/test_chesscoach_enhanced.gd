extends SceneTree
## Headless checks for Chess Coach Enhanced (presentation over Direct game.tscn).
## Run: godot --headless --path . --script res://tools/test_chesscoach_enhanced.gd

const SCENE := "res://games/chesscoach/enhanced/game.tscn"
const DIRECT := "res://games/chesscoach/direct/game.tscn"
const BoardScript := preload("res://games/chesscoach/direct/chess_board.gd")
const TrayScript := preload("res://games/chesscoach/direct/tray.gd")
const SquareScript := preload("res://games/chesscoach/direct/square.gd")
const GameEditorScript := preload("res://games/chesscoach/direct/game_editor.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: chesscoach_enhanced ", msg)
	else:
		print("SMOKE FAIL: chesscoach_enhanced ", msg)
		_fail += 1


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_scene()
	print("chesscoach_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("chesscoach", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("chesscoach", "direct").is_playable(), "registry: direct still playable")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(inst.direct == null, "Direct scene not loaded until play")

	var back: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			back = b
			break
	_check(back != null and back.focus_mode == Control.FOCUS_NONE,
		"Back to Arcade present, FOCUS_NONE")

	# Enter -> play: Direct scene instanced with Direct scripts.
	root.push_input(_key(KEY_ENTER))
	await _frames(10)
	_check(inst.state == inst.PLAY and inst.direct != null, "Enter begins and loads Direct")
	_check(not inst._cards["title"].visible and inst._hud.visible, "title hidden, HUD shown")
	var d: Control = inst.direct
	_check(d.scene_file_path == DIRECT, "embedded scene is Direct game.tscn")
	_check(d.get_script() != null and d.get_script().resource_path.ends_with("direct/game.gd"),
		"root uses Direct game.gd (shared) [%s]" % (d.get_script().resource_path if d.get_script() else "null"))
	_check(inst.board != null and inst.board.get_script() == BoardScript,
		"board uses Direct chess_board.gd (shared)")
	_check(d.get_node("white-tray").get_script() == TrayScript
			and d.get_node("black-tray").get_script() == TrayScript,
		"trays use Direct tray.gd (shared)")
	_check(inst.editor.get_script() == GameEditorScript, "Editor uses Direct game_editor.gd")
	var toolbar: Control = d.get_node_or_null("Toolbar")
	_check(toolbar != null and not toolbar.visible, "Direct toolbar hidden; Enhanced owns chrome")

	# Wait for Direct FEN boot + Enhanced restyle.
	await _frames(12)
	_check(inst.board.pieces_on_board() == 32,
		"INIT_FEN places 32 pieces via Direct (got %d)" % inst.board.pieces_on_board())
	_check(inst.board.INIT_FEN == BoardScript.INIT_FEN, "shares Direct INIT_FEN const")

	# Wood palette applied (not the original blue).
	var a1: ColorRect = inst.board.get_node("ranks/rank1/a1")
	var b1: ColorRect = inst.board.get_node("ranks/rank1/b1")
	_check(a1.get_script() == SquareScript and b1.get_script() == SquareScript,
		"squares still use Direct square.gd")
	_check(a1.dark != b1.dark, "a1/b1 keep alternating dark flags")
	_check(a1.color.is_equal_approx(inst.WOOD_DARK) or a1.color.is_equal_approx(inst.WOOD_LIGHT),
		"a1 painted walnut/cream (got %s)" % a1.color)
	_check(not a1.color.is_equal_approx(Color(0x618fb8ff)) \
			and not a1.color.is_equal_approx(Color(0xbfd9f2ff)),
		"original blue palette replaced")

	# Piece placement parity vs a bare Direct twin.
	var twin: Node = (load(DIRECT) as PackedScene).instantiate()
	root.add_child(twin)
	await _frames(10)
	var tboard: Panel = twin.get_node("board")
	_check(tboard.pieces_on_board() == 32, "bare Direct twin also has 32")
	var pieces: Node = inst.board.get_node("pieces")
	var tpieces: Node = tboard.get_node("pieces")
	for name in ["R0", "K0", "r0", "k0", "P0", "p0"]:
		_check(pieces.get_node_or_null(name) != null and tpieces.get_node_or_null(name) != null,
			"piece %s on Enhanced and Direct twin" % name)
	# a1 / a8 seat parity (local to each board).
	var ea1: ColorRect = inst.board.get_node("ranks/rank1/a1")
	var ea8: ColorRect = inst.board.get_node("ranks/rank8/a8")
	var R0: Sprite2D = pieces.get_node("R0")
	var r0: Sprite2D = pieces.get_node("r0")
	_check(R0.global_position.distance_to(ea1.global_position) < 2.0,
		"Enhanced R0 on a1 (dist=%.1f)" % R0.global_position.distance_to(ea1.global_position))
	_check(r0.global_position.distance_to(ea8.global_position) < 2.0,
		"Enhanced r0 on a8 (dist=%.1f)" % r0.global_position.distance_to(ea8.global_position))
	twin.queue_free()
	await _frames(2)

	# Move list parsed from Direct Editor json_moves.
	_check(inst.moves.size() > 20, "parsed recorded moves from Direct Editor (n=%d)" % inst.moves.size())
	var last = inst.moves[inst.moves.size() - 1]
	_check(last is Array and str(last[3]).begins_with("Qe8"),
		"last recorded SAN is Qe8# (got %s)" % str(last[3]))

	# Reset via Enhanced action (clears then restores INIT_FEN).
	inst._do_reset()
	await _frames(4)
	_check(inst.board.pieces_on_board() == 32, "Reset restores 32 pieces")
	_check(inst.captures_seen == 0 and not inst.replaying, "Reset clears replay counters")

	# Clear via Direct API still works through the shared board.
	inst.board.clear_board()
	await _frames(2)
	_check(inst.board.pieces_on_board() == 0, "clear_board empties via Direct")
	_check(d.get_node("white-tray").get_child_count() == 16
			and d.get_node("black-tray").get_child_count() == 16,
		"clear stows 16+16 into Direct trays")
	inst._do_reset()
	await _frames(4)
	_check(inst.board.pieces_on_board() == 32, "Reset after clear restores 32")

	# Replay starts Direct AnimationPlayer.
	inst._do_replay()
	await _frames(8)
	_check(inst.player != null and (inst.player.is_playing() or inst.replaying),
		"Replay starts Direct AnimationPlayer / replaying flag")
	_check(inst._particles.size() > 0 or inst._banner_t > 0.0, "Replay juice (particles or banner)")

	# Esc -> PauseOverlay, Esc again -> arcade
	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses the tree")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
