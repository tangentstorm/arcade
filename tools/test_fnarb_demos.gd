extends SceneTree
## Headless checks for the fnarbmlyx demo ports (fnarb_overlap, fnarb_ast, fnarb_binary_tree,
## fnarb_binary_adder, fnarb_binary_space). Each runs in a 1920×1080 SubViewport stage.
## Run: godot --headless --path . --script res://tools/test_fnarb_demos.gd

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: fnarb_demos ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _load(id: String) -> Node:
	var game: Node = load("res://games/%s/direct/game.tscn" % id).instantiate()
	root.add_child(game)
	return game


func _demo(game: Node) -> Node:
	return game.get_node("Stage/Viewport/Demo")


func _run() -> void:
	# every tile: a 1920×1080 SubViewport with the demo inside
	for id in ["fnarb_overlap", "fnarb_ast", "fnarb_binary_tree", "fnarb_binary_adder", "fnarb_binary_space"]:
		var g := _load(id)
		await _frames(2)
		var vp: SubViewport = g.get_node("Stage/Viewport")
		_check(vp.size == Vector2i(1920, 1080) and _demo(g) != null, id + ": demo in 1920×1080 stage")
		g.queue_free()
		await process_frame

	# overlap: 9 boxes at (50 + 75x, 50 + 75y); hover + press + drag onto a neighbour → gray / black
	var g := _load("fnarb_overlap")
	await _frames(2)
	var d := _demo(g)
	_check(d.boxes.size() == 9 and d.boxes[1].position == Vector2(125, 50), "overlap: 3×3 boxes, row-major")
	d.on_mouse_enter(d.boxes[0])
	_check(d.subject == d.boxes[0] and d.boxes[0].color == Color.CORNFLOWER_BLUE, "overlap: hover highlights")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(60, 60)
	d._input(press)
	_check(d.boxes[0].color == Color.GOLDENROD and d.offset == Vector2(-10, -10), "overlap: press → goldenrod, grab offset")
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(120, 60)
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	d._input(mv)
	_check(d.subject.position == Vector2(110, 50), "overlap: drag moves the box")
	_check(d.subject.color == Color.BLACK and d.boxes[1].color == Color.DIM_GRAY, "overlap: overlapping held box → black, other → dim gray")
	g.queue_free()
	await process_frame

	# AST: seeded tree is deterministic (seed 82076)
	g = _load("fnarb_ast")
	await _frames(3)
	d = _demo(g).get_node("ASTNodeDemo")
	_check(d.tree != null and d.tree.count > 30, "ast: built a tree of %d nodes" % d.tree.count)
	_check(d.get_child_count() == 1, "ast: one rendered root node")
	g.queue_free()
	await process_frame

	# Binary adder: speed the 1 s step timer up and check the 3 + 7 = 10 (1010) result row.
	g = _load("fnarb_binary_adder")
	await _frames(2)
	d = _demo(g)
	var adder: Control = d.get_node("Adder")
	var timer: Timer = adder.get_node("Timer")
	timer.wait_time = 0.02
	timer.start()
	await create_timer(3.0).timeout
	var bits := ""
	for i in [3, 2, 1, 0]:
		bits += "1" if adder.get_node("r/bit%d" % i).color == adder.I else "0"
	_check(bits == "1010", "adder: result row reads %s (3 + 7 = 1010)" % bits)
	var carries := ""
	for i in [4, 3, 2, 1]:
		carries += "1" if adder.get_node("c/bit%d" % i).color == adder.I else "0"
	_check(carries == "0111", "adder: carry row reads %s" % carries)
	g.queue_free()
	await process_frame

	if _fail == 0:
		print("test_fnarb_demos: OK")
		quit(0)
	else:
		print("test_fnarb_demos: FAILED (%d)" % _fail)
		quit(1)
