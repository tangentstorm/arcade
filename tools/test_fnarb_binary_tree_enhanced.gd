extends SceneTree
## Headless checks for Fnarb Binary Tree Enhanced (presentation over the Direct tree scene).
## Run: godot --headless --path . --script res://tools/test_fnarb_binary_tree_enhanced.gd

const SCENE := "res://games/fnarb_binary_tree/enhanced/game.tscn"
const DIRECT := "res://games/fnarb_binary_tree/direct/game.tscn"
const DEMO := "res://games/fnarb_binary_tree/direct/binary_tree.tscn"
const TreeScript := preload("res://games/fnarb_binary_tree/direct/binary_tree.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: fnarb_binary_tree_enhanced ", msg)
	else:
		print("SMOKE FAIL: fnarb_binary_tree_enhanced ", msg)
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
	print("fnarb_binary_tree_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


## Independent reference: where Direct build_node draws each disk (heap-indexed, 2i = -dx).
func _ref_points(demo: Control) -> Dictionary:
	var out := {}
	var stack := [[1, demo.position + demo.size * 0.5, int(demo.DEPTH)]]
	while stack.size():
		var it: Array = stack.pop_back()
		out[it[0]] = it[1]
		if it[2] > 0:
			var dx: int = ((demo.node_radius + demo.gap) * (1 << it[2])) / 2
			stack.append([it[0] * 2, it[1] + Vector2(-dx, 40), it[2] - 1])
			stack.append([it[0] * 2 + 1, it[1] + Vector2(dx, 40), it[2] - 1])
	return out


func _no_rules_copy() -> void:
	var src := FileAccess.get_file_as_string("res://games/fnarb_binary_tree/enhanced/game.gd")
	_check(src.contains("preload(\"res://games/fnarb_binary_tree/direct/binary_tree.tscn\")"),
		"preloads Direct binary_tree.tscn")
	_check(not src.contains("func build_node"), "no build_node copy")
	_check(not src.contains("0x1f77b4"), "no palette copy (colours read from Direct)")
	_check(not src.contains("draw_circle(xy"), "no Direct disk drawing copy")
	var files: PackedStringArray = DirAccess.get_files_at("res://games/fnarb_binary_tree/enhanced/")
	for f in files:
		if f.ends_with(".gd") and f != "game.gd":
			_check(false, "unexpected extra script in enhanced/: " + f)


func _test_scene() -> void:
	_no_rules_copy()
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")

	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("fnarb_binary_tree", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("fnarb_binary_tree", "direct").is_playable(), "registry: direct still playable")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(inst.demo == null and not inst._clip.visible, "Direct tree not shown until Start")
	_check(inst.STAGE == Vector2(1280, 720), "1280×720 stage")

	var backs := 0
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			backs += 1
			_check(b.focus_mode == Control.FOCUS_NONE, "Back to Arcade FOCUS_NONE (%s)" % b.get_path())
		if b.text == "Start":
			_check(b.focus_mode == Control.FOCUS_NONE, "Start FOCUS_NONE")
	_check(backs >= 2, "Back to Arcade on title card + HUD (%d)" % backs)

	root.push_input(_key(KEY_SPACE))
	await _frames(4)
	_check(inst.state == inst.PLAY and inst.demo != null, "Space starts and loads the Direct tree")
	_check(not inst._cards["title"].visible and inst._hud.visible and inst._clip.visible,
		"title hidden, HUD + field shown")
	var d: Control = inst.demo
	_check(d.scene_file_path == DEMO and d.get_script() == TreeScript, "tree is Direct binary_tree.tscn/.gd")
	_check(inst._viewport.size == Vector2i(1920, 1080), "Direct tree in its native 1920×1080 viewport")
	_check(inst._clip.clip_contents, "field is clipped")

	# Parity vs a bare Direct twin: same script, same params, same layout and node positions.
	var twin: Node = (load(DIRECT) as PackedScene).instantiate()
	root.add_child(twin)
	await _frames(3)
	var td: Control = twin.get_node("Stage/Viewport/Demo")
	_check(td.get_script() == d.get_script(), "parity: same Direct script")
	_check(td.DEPTH == d.DEPTH and td.node_radius == d.node_radius and td.gap == d.gap,
		"parity: DEPTH/radius/gap match (%d/%d/%d)" % [d.DEPTH, d.node_radius, d.gap])
	_check(td.colors == d.colors, "parity: palette matches")
	_check(td.position == d.position and td.size == d.size,
		"parity: Direct layout matches (pos %s size %s)" % [d.position, d.size])
	var pts: Dictionary = inst.node_points()
	var ref := _ref_points(td)
	_check(pts.size() == 63 and inst.node_count() == 63, "63 nodes (depth 5)")
	var same := pts.size() == ref.size()
	for k in ref:
		if not pts.has(k) or pts[k].distance_to(ref[k]) > 0.01:
			same = false
	_check(same, "parity: overlay node positions match Direct build_node layout")
	_check(inst.node_color(1) == td.colors[0] and inst.node_color(63) == td.colors[5],
		"overlay colours follow Direct colors[DEPTH - depth]")
	twin.queue_free()

	# Framing: whole tree inside the field.
	var inside := true
	var field := Rect2(inst.FIELD_POS, inst.FIELD)
	for k in pts:
		if not field.has_point(inst.to_stage(pts[k])):
			inside = false
	_check(inside, "every node lands inside the field (k=%.3f)" % inst._k)
	_check(field.end.x <= 1280 and field.end.y <= 720, "field fits the stage")

	# Juice: grow-in reveal, then a traversal wave.
	_check(inst.grow < 1.0 and inst._clip.size.y < inst.FIELD.y, "grow-in reveal starts clipped")
	await create_timer(0.5).timeout
	_check(inst._particles.size() > 0, "row pop particles while growing")
	await create_timer(2.2).timeout
	_check(inst.grow == 1.0 and inst._clip.size.y == inst.FIELD.y, "fully grown, full field")
	await create_timer(0.6).timeout
	_check(inst.cursor >= 1 and inst.visited.size() >= 2, "traversal wave advancing (%d)" % inst.visited.size())
	_check(inst.order == inst.traversal(0) and inst.order[0] == 1 and inst.order[1] == 2, "BFS order")

	root.push_input(_key(KEY_TAB))
	await _frames(2)
	_check(inst.mode == 1 and inst.order.slice(0, 4) == [1, 2, 4, 8], "Tab → pre-order")
	_check(inst.traversal(2)[0] == 32 and inst.traversal(3)[-1] == 1, "in-order / post-order")
	_check(inst.traversal(2).size() == 63 and inst.traversal(3).size() == 63, "traversals cover all nodes")

	# Hover inspector.
	inst._mouse_override = inst.to_stage(pts[5])
	await _frames(2)
	_check(inst.hover == 5, "hover picks node #5 (got %d)" % inst.hover)
	_check(inst.path_of(5) == "LR" and inst._inspect_label.text.contains("#5"), "inspector shows #5 path LR")
	inst._mouse_override = Vector2(5, 5)
	await _frames(2)
	_check(inst.hover == 0, "no hover off-tree")
	inst._mouse_override = null

	root.push_input(_key(KEY_R))
	await _frames(2)
	_check(inst.grow < 0.2 and inst.visited.is_empty(), "R regrows")
	_check(inst.demo == d, "R keeps the same Direct tree (presentation reset only)")

	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses the tree")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again → Back to Arcade")
