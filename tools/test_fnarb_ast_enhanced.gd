extends SceneTree
## Headless checks for Fnarb Boolean AST Enhanced (presentation over Direct demo).
## Run: godot --headless --path . --script res://tools/test_fnarb_ast_enhanced.gd

const SCENE := "res://games/fnarb_ast/enhanced/game.tscn"
const DIRECT := "res://games/fnarb_ast/direct/game.tscn"
const DEMO := "res://games/fnarb_ast/direct/ast_node_demo.tscn"
const DemoScript := preload("res://games/fnarb_ast/direct/ast_node_demo.gd")
const AstScript := preload("res://games/fnarb_ast/direct/ast_node.gd")
const GridScript := preload("res://games/fnarb_ast/direct/shaded_grid.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: fnarb_ast_enhanced ", msg)
	else:
		print("SMOKE FAIL: fnarb_ast_enhanced ", msg)
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
	print("fnarb_ast_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _no_rules_copy() -> void:
	var src := FileAccess.get_file_as_string("res://games/fnarb_ast/enhanced/game.gd")
	_check(src.contains("preload(\"res://games/fnarb_ast/direct/ast_node_demo.tscn\")"),
		"preloads Direct ast_node_demo.tscn")
	_check(not src.contains("func build_subtree"), "no build_subtree rules copy")
	_check(not src.contains("func build_scene"), "no build_scene rules copy")
	_check(not src.contains("func rebuild"), "no rebuild rules copy")
	_check(not src.contains("class TreeNode"), "no TreeNode rules copy")
	_check(not src.contains("func layout():"), "no ASTNode.layout copy")
	var files: PackedStringArray = DirAccess.get_files_at("res://games/fnarb_ast/enhanced/")
	for f in files:
		if f.ends_with(".gd") and f != "game.gd":
			_check(false, "unexpected extra script in enhanced/: " + f)


func _ops_of(root: Control) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while stack.size():
		var n: Control = stack.pop_back()
		if n.get_script() != AstScript:
			continue
		out.append(int(n.op))
		for c in n.get_children():
			stack.append(c)
	out.sort()
	return out


func _test_scene() -> void:
	_no_rules_copy()
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")
	_check(load(DEMO) is PackedScene, "Direct demo scene still loads")

	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("fnarb_ast", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("fnarb_ast", "direct").is_playable(), "registry: direct still playable")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(inst.demo == null and not inst._clip.visible, "Direct AST not shown until Start")
	_check(inst.STAGE == Vector2(1280, 720), "1280×720 stage")
	_check(inst.FIELD == Vector2(960, 540), "960×540 field (½ of 1920×1080)")

	var backs := 0
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			backs += 1
			_check(b.focus_mode == Control.FOCUS_NONE, "Back to Arcade FOCUS_NONE (%s)" % b.get_path())
		if b.text == "Start":
			_check(b.focus_mode == Control.FOCUS_NONE, "Start FOCUS_NONE")
	_check(backs >= 2, "Back to Arcade on title card + HUD (%d)" % backs)

	root.push_input(_key(KEY_SPACE))
	await _frames(8)
	_check(inst.state == inst.PLAY and inst.demo != null, "Space starts and loads the Direct AST")
	_check(not inst._cards["title"].visible and inst._hud.visible and inst._clip.visible,
		"title hidden, HUD + field shown")
	var d: ColorRect = inst.demo
	_check(d.scene_file_path == DEMO and d.get_script() == GridScript,
		"demo is Direct ast_node_demo.tscn (shaded_grid.gd)")
	_check(inst.ast != null and inst.ast.get_script() == DemoScript,
		"ASTNodeDemo uses Direct ast_node_demo.gd")
	_check(inst._viewport.size == Vector2i(1920, 1080), "Direct AST in its native 1920×1080 viewport")
	_check(inst._clip.clip_contents, "field is clipped")
	_check(not inst._vp_box.stretch and inst._vp_box.scale == Vector2(0.5, 0.5),
		"native viewport scaled ½ into 960×540 field")

	# Let rebuild settle, then re-collect if needed.
	await _frames(4)
	if inst.node_count() == 0:
		inst._collect_nodes()
	_check(inst.node_count() > 30, "collected AST nodes (%d)" % inst.node_count())
	_check(inst.ast.rng_seed == 82076, "Direct seed 82076")

	# Parity vs a bare Direct twin: same seed, same tree ops, same scripts.
	var twin: Node = (load(DIRECT) as PackedScene).instantiate()
	root.add_child(twin)
	await _frames(4)
	var td_grid: ColorRect = twin.get_node("Stage/Viewport/Demo")
	var td: Control = td_grid.get_node("ASTNodeDemo")
	_check(td_grid.get_script() == GridScript and td.get_script() == DemoScript,
		"parity: twin uses Direct shaded_grid + ast_node_demo")
	_check(td.rng_seed == inst.ast.rng_seed and td.rng_seed == 82076, "parity: seed matches")
	_check(td.tree != null and inst.ast.tree != null, "parity: both have TreeNode roots")
	_check(td.tree.count == inst.ast.tree.count and td.tree.height == inst.ast.tree.height,
		"parity: tree count/height match (%d / %d)" % [inst.ast.tree.count, inst.ast.tree.height])
	var eroot: Control = inst.ast.get_child(0)
	var troot: Control = td.get_child(0)
	_check(eroot.get_script() == AstScript and troot.get_script() == AstScript,
		"parity: roots use Direct ast_node.gd")
	_check(int(eroot.op) == int(troot.op) and eroot.text == troot.text,
		"parity: root op/text match (%s)" % eroot.text)
	var eops := _ops_of(eroot)
	var tops := _ops_of(troot)
	_check(eops == tops and eops.size() == inst.node_count(),
		"parity: all node ops match Direct twin (%d)" % eops.size())
	# Overlay centres track Direct link_points.
	var centres_ok := true
	for i in inst.node_count():
		var n: Control = inst._nodes[i]
		var expected: Vector2 = n.global_position + n.link_point()
		if inst.node_center_vp(i).distance_to(expected) > 0.01:
			centres_ok = false
	_check(centres_ok, "overlay centres follow Direct link_point()")
	twin.queue_free()

	# Field fits stage.
	_check(inst.FIELD_POS.x + inst.FIELD.x <= 1280 and inst.FIELD_POS.y + inst.FIELD.y <= 720,
		"field fits the stage")

	# Juice: grow-in reveal, then a traversal wave.
	_check(inst.grow < 1.0 and inst._clip.size.y < inst.FIELD.y, "grow-in reveal starts clipped")
	await create_timer(0.45).timeout
	_check(inst._particles.size() > 0, "depth pop particles while growing")
	await create_timer(2.0).timeout
	_check(inst.grow == 1.0 and inst._clip.size.y == inst.FIELD.y, "fully grown, full field")
	await create_timer(0.5).timeout
	_check(inst.cursor >= 1 and inst.visited.size() >= 2, "traversal wave advancing (%d)" % inst.visited.size())
	_check(inst.order == inst.traversal(0) and inst.order.size() == inst.node_count(), "BFS order covers all")
	_check(inst.order.size() > 0 and inst._depths[inst.order[0]] == 0, "BFS starts at root")

	root.push_input(_key(KEY_TAB))
	await _frames(2)
	_check(inst.mode == 1 and inst.order.size() == inst.node_count(), "Tab → pre-order")
	_check(inst.order[0] == 0, "pre-order starts at root index 0")
	_check(inst.traversal(3)[-1] == 0, "post-order ends at root")
	_check(inst.traversal(2).size() == inst.node_count(), "in-order covers all nodes")

	# Hover inspector on root.
	inst._mouse_override = inst.to_stage(inst.node_center_vp(0))
	await _frames(2)
	_check(inst.hover == 0, "hover picks root (got %d)" % inst.hover)
	_check(inst._paths[0] == "root" and inst._inspect_label.text.contains("root"),
		"inspector shows root path")
	inst._mouse_override = Vector2(5, 5)
	await _frames(2)
	_check(inst.hover == -1, "no hover off-tree")
	inst._mouse_override = null

	root.push_input(_key(KEY_R))
	await _frames(2)
	_check(inst.grow < 0.2 and inst.visited.is_empty(), "R regrows")
	_check(inst.demo == d, "R keeps the same Direct AST (presentation reset only)")

	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses the tree")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again → Back to Arcade")
