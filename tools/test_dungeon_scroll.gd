extends SceneTree
## Headless checks for dungeon-scroll-demo Direct.
## Run: godot --headless --path . --script res://tools/test_dungeon_scroll.gd

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: dungeon_scroll ", msg)
		_fail += 1


func _snapshot(g: Node3D) -> Dictionary:
	var d := {}
	for c in g.get_used_cells():
		d[c] = [g.get_cell_item(c), g.get_cell_item_orientation(c)]
	return d


func _initialize() -> void:
	var scene: PackedScene = load("res://games/dungeon_scroll/direct/game.tscn")
	_check(scene != null and scene.can_instantiate(), "direct scene loads")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var t = game.get_node("Template")
	var g = game.get_node("Generated")
	var lib: MeshLibrary = t.mesh_library
	var floor_i := lib.find_item_by_name("floor")
	var allowed := [floor_i, lib.find_item_by_name("floor-detail"),
		lib.find_item_by_name("rocks"), lib.find_item_by_name("wall")]
	_check(lib.get_item_list().size() == 21 and not allowed.has(-1), "Kenney meshlib: 21 items, rule tiles found")
	_check(t.get_used_cells().size() == 140, "template has the source's 140 cells")
	_check(g.get_used_cells().size() == 140, "generated starts with the source's baked 140 cells")
	_check(game.parsed_rules.has(floor_i) and game.parsed_rules[floor_i].size() == 4, "default rules parsed: floor -> 4 options")

	game.generate(42)
	var tmpl := _snapshot(t)
	var gen := _snapshot(g)
	var same_keys := tmpl.keys().size() == gen.keys().size()
	var ok := true
	var floors := 0
	var changed := 0
	for c in tmpl:
		if not gen.has(c) or gen[c][1] != tmpl[c][1]:
			same_keys = false
			continue
		if tmpl[c][0] == floor_i:
			floors += 1
			if not allowed.has(gen[c][0]):
				ok = false
			if gen[c][0] != floor_i:
				changed += 1
		elif gen[c][0] != tmpl[c][0]:
			ok = false
	_check(same_keys, "generated = same cells + orientations as template")
	_check(ok, "only floor is rewritten, into floor/floor-detail/rocks/wall")
	_check(floors > 0 and changed > 0 and changed < floors, "some floor tiles rewritten (%d/%d)" % [changed, floors])

	game.generate(42)
	_check(_snapshot(g) == gen, "same seed -> same layout")
	game.generate(7)
	_check(_snapshot(g) != gen, "new seed -> new layout")

	var ev := InputEventKey.new()
	ev.keycode = KEY_R
	ev.pressed = true
	var before := _snapshot(g)
	game._unhandled_key_input(ev)
	_check(_snapshot(g) != before, "R regenerates")
	game.queue_free()
	print("VERIFY DONE: ", _fail)
	quit(_fail)
