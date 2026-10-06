extends SceneTree
## Headless checks for Chess Coach Direct: FEN setup places 32 pieces; clear empties the board.
## Run: godot --headless --path . --script res://tools/test_chesscoach.gd

const SCENE := "res://games/chesscoach/direct/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: chesscoach ", msg)
	else:
		print("SMOKE FAIL: chesscoach ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load(SCENE)
	_check(packed != null, "loads game.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	# Board defers FEN setup two frames for layout.
	for i in 8:
		await process_frame

	var board: Panel = scene.get_node("board")
	_check(board != null and board.has_method("setup_board"), "board has setup_board")
	_check(board.pieces_on_board() == 32, "INIT_FEN places 32 pieces (got %d)" % board.pieces_on_board())

	var pieces: Node = board.get_node("pieces")
	_check(pieces.get_node_or_null("R0") != null, "white rook R0 on board")
	_check(pieces.get_node_or_null("K0") != null, "white king K0 on board")
	_check(pieces.get_node_or_null("r0") != null, "black rook r0 on board")
	_check(pieces.get_node_or_null("k0") != null, "black king k0 on board")

	# a1 / a8 should host white/black rook near the square origin.
	var a1: ColorRect = board.get_node("ranks/rank1/a1")
	var a8: ColorRect = board.get_node("ranks/rank8/a8")
	var R0: Sprite2D = pieces.get_node("R0")
	var r0: Sprite2D = pieces.get_node("r0")
	_check(R0.global_position.distance_to(a1.global_position) < 2.0,
		"R0 sits on a1 (dist=%.1f)" % R0.global_position.distance_to(a1.global_position))
	_check(r0.global_position.distance_to(a8.global_position) < 2.0,
		"r0 sits on a8 (dist=%.1f)" % r0.global_position.distance_to(a8.global_position))

	board.clear_board()
	await process_frame
	_check(board.pieces_on_board() == 0, "clear_board empties pieces (got %d)" % board.pieces_on_board())
	var white_tray: Node = scene.get_node("white-tray")
	var black_tray: Node = scene.get_node("black-tray")
	_check(white_tray.get_child_count() == 16, "clear stows 16 white pieces (got %d)" % white_tray.get_child_count())
	_check(black_tray.get_child_count() == 16, "clear stows 16 black pieces (got %d)" % black_tray.get_child_count())

	board.setup_board(board.INIT_FEN)
	await process_frame
	_check(board.pieces_on_board() == 32, "setup_board again places 32 (got %d)" % board.pieces_on_board())

	_check(scene.get_node_or_null("%BackButton") != null, "Back to Arcade button present")

	scene.queue_free()
	await process_frame
	quit(1 if _fail else 0)
