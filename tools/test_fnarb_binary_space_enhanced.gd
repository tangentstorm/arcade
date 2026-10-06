extends SceneTree
## Headless checks for Fnarb Binary Space Enhanced (presentation over Direct demo).
## Run: godot --headless --path . --script res://tools/test_fnarb_binary_space_enhanced.gd

const SCENE := "res://games/fnarb_binary_space/enhanced/game.tscn"
const DIRECT := "res://games/fnarb_binary_space/direct/game.tscn"
const DEMO := "res://games/fnarb_binary_space/direct/binary_space.tscn"
const TruthScript := preload("res://games/fnarb_binary_space/direct/truth_table.gd")
const GridScript := preload("res://games/fnarb_binary_space/direct/shaded_grid.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: fnarb_binary_space_enhanced ", msg)
	else:
		print("SMOKE FAIL: fnarb_binary_space_enhanced ", msg)
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
	print("fnarb_binary_space_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _no_rules_copy() -> void:
	## Enhanced scripts must not redefine Direct truth-table / grid helpers.
	var src := FileAccess.get_file_as_string("res://games/fnarb_binary_space/enhanced/game.gd")
	_check(src.contains("preload(\"res://games/fnarb_binary_space/direct/binary_space.tscn\")") \
			or src.contains("preload('res://games/fnarb_binary_space/direct/binary_space.tscn')"),
		"preloads Direct binary_space.tscn")
	_check(not src.contains("func _set_nvars"), "no _set_nvars rules copy")
	_check(not src.contains("func _set_bits"), "no _set_bits rules copy")
	_check(not src.contains("func set_seed"), "no set_seed rules copy")
	_check(not src.contains("func _set_cellSize"), "no _set_cellSize rules copy")
	_check(DirAccess.open("res://games/fnarb_binary_space/enhanced/") != null, "enhanced/ exists")
	var files: PackedStringArray = DirAccess.get_files_at("res://games/fnarb_binary_space/enhanced/")
	for f in files:
		if f.ends_with(".gd") and f != "game.gd":
			_check(false, "unexpected extra script in enhanced/: " + f)


func _test_scene() -> void:
	_no_rules_copy()
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")
	_check(load(DEMO) is PackedScene, "Direct demo scene still loads")

	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("fnarb_binary_space", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("fnarb_binary_space", "direct").is_playable(),
		"registry: direct still playable")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(inst.demo == null, "Direct demo not loaded until play")
	_check(inst.STAGE == Vector2(1280, 720), "1280×720 stage")
	_check(inst.FIELD == Vector2(960, 540), "960×540 field (½ of 1920×1080)")

	# Back to Arcade FOCUS_NONE (title card + HUD).
	var backs: Array = []
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			backs.append(b)
			_check(b.focus_mode == Control.FOCUS_NONE, "Back to Arcade FOCUS_NONE (%s)" % b.get_path())
	_check(backs.size() >= 1, "Back to Arcade present")

	# Space → play: Direct demo instanced with Direct scripts.
	root.push_input(_key(KEY_SPACE))
	await _frames(10)
	_check(inst.state == inst.PLAY and inst.demo != null, "Space begins and loads Direct demo")
	_check(not inst._cards["title"].visible and inst._hud.visible, "title hidden, HUD shown")
	_check(inst._vp_box.visible, "demo viewport visible")
	var d: Node = inst.demo
	_check(d.scene_file_path == DEMO, "embedded scene is Direct binary_space.tscn")
	_check(inst.bg != null and inst.bg.get_script() == GridScript,
		"background uses Direct shaded_grid.gd (shared)")
	_check(inst.camera != null and inst.camera.position == Vector2(960, 540),
		"Camera2D kept at Direct (960, 540)")
	_check(inst.hidden_box != null and not inst.hidden_box.visible,
		"hidden first VBoxContainer stays hidden (Direct quirk)")
	_check(inst.rows != null and inst.rows.get_child_count() == 32,
		"VBoxContainer2 has 32 truth-table rows")

	# Shared Direct widgets: first visible row uses Direct truth_table.gd.
	var row0: Control = inst.rows.get_child(0) as Control
	_check(row0 != null and row0.get_script() == TruthScript,
		"row0 uses Direct truth_table.gd (shared)")
	_check(int(row0.get("bits")) == 4294967295, "row0 bits = all-ones (Direct)")
	_check(row0.modulate.a >= 0.5, "row0 is lit (power-of-two / full)")

	# Field fits stage letterbox math.
	_check(inst.FIELD_POS.x + inst.FIELD.x <= inst.STAGE.x \
			and inst.FIELD_POS.y + inst.FIELD.y <= inst.STAGE.y,
		"field fits inside stage")

	# Parity vs bare Direct twin: all 32 row bits + modulate match.
	var twin_root: Node = (load(DIRECT) as PackedScene).instantiate()
	root.add_child(twin_root)
	await _frames(4)
	var twin_demo: Node = twin_root.get_node("Stage/Viewport/Demo")
	var twin_rows: VBoxContainer = twin_demo.get_node("VBoxContainer2")
	_check(twin_rows.get_child_count() == 32, "twin has 32 rows")
	var twin_hidden: VBoxContainer = twin_demo.get_node("VBoxContainer")
	_check(not twin_hidden.visible, "twin hidden box stays hidden")
	# Spot-check shared scripts on a few rows.
	for i in [0, 1, 2, 4, 8, 16, 31]:
		var er: Control = inst.rows.get_child(i) as Control
		var tr: Control = twin_rows.get_child(i) as Control
		_check(er.get_script() == TruthScript and tr.get_script() == TruthScript,
			"parity: row%d both use Direct truth_table.gd" % i)
	var mismatch := 0
	var lit_e := 0
	var lit_t := 0
	for i in 32:
		var er2: Control = inst.rows.get_child(i) as Control
		var tr2: Control = twin_rows.get_child(i) as Control
		if int(er2.get("bits")) != int(tr2.get("bits")):
			mismatch += 1
		if absf(er2.modulate.a - tr2.modulate.a) > 0.01:
			mismatch += 1
		if er2.modulate.a >= 0.5:
			lit_e += 1
		if tr2.modulate.a >= 0.5:
			lit_t += 1
	_check(mismatch == 0, "parity: all 32 row bits + modulate match Direct twin")
	_check(lit_e == lit_t and lit_e == 6, "parity: 6 lit rows (0,1,2,4,8,16) match twin (%d)" % lit_e)
	_check(inst._lit_count == 6 and inst._faded_count == 26,
		"HUD lit/faded counts 6/26")

	# Spot-check a few Direct bit patterns.
	_check(int(inst.rows.get_child(1).get("bits")) == int(twin_rows.get_child(1).get("bits")),
		"parity: row1 bits match")
	_check(int(inst.rows.get_child(16).get("bits")) == 4294901760,
		"row16 bits = 4294901760 (Direct)")
	_check(inst.rows.get_child(3).modulate.a < 0.5, "row3 faded (non-power-of-two)")

	# Juice: scan advances and fires particles/floaters.
	await create_timer(0.8).timeout
	_check(inst._scan_row >= 0, "scan row advanced (got %d)" % inst._scan_row)
	_check(inst._particles.size() > 0 or inst._floaters.size() > 0 or inst._banner_t > 0.0,
		"juice live after scan (particles/floaters/banner)")

	# Let scan wrap once for reveal banner.
	await create_timer(2.0).timeout
	_check(inst._revealed or inst._scan_row >= 0, "reveal completed or scan still walking")

	twin_root.queue_free()
	await _frames(2)

	# Esc → PauseOverlay → arcade
	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses the tree")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again → Back to Arcade")
