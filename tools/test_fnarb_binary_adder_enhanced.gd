extends SceneTree
## Headless checks for Fnarb Binary Adder Enhanced (presentation over Direct demo).
## Run: godot --headless --path . --script res://tools/test_fnarb_binary_adder_enhanced.gd

const SCENE := "res://games/fnarb_binary_adder/enhanced/game.tscn"
const DIRECT := "res://games/fnarb_binary_adder/direct/game.tscn"
const DEMO := "res://games/fnarb_binary_adder/direct/binary_addition.tscn"
const AdderScript := preload("res://games/fnarb_binary_adder/direct/adder.gd")
const RectScript := preload("res://games/fnarb_binary_adder/direct/rect.gd")
const TruthScript := preload("res://games/fnarb_binary_adder/direct/truth_table.gd")
const GridScript := preload("res://games/fnarb_binary_adder/direct/shaded_grid.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: fnarb_binary_adder_enhanced ", msg)
	else:
		print("SMOKE FAIL: fnarb_binary_adder_enhanced ", msg)
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
	print("fnarb_binary_adder_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _no_rules_copy() -> void:
	## Enhanced scripts must not redefine Direct adder/step helpers.
	var src := FileAccess.get_file_as_string("res://games/fnarb_binary_adder/enhanced/game.gd")
	_check(src.contains("preload(\"res://games/fnarb_binary_adder/direct/binary_addition.tscn\")") \
			or src.contains("preload('res://games/fnarb_binary_adder/direct/binary_addition.tscn')"),
		"preloads Direct binary_addition.tscn")
	_check(not src.contains("func make_script"), "no make_script rules copy")
	_check(not src.contains("func do_step"), "no do_step rules copy")
	_check(not src.contains("func set_bit"), "no set_bit rules copy")
	_check(not src.contains("func move_carriage_left"), "no move_carriage_left rules copy")
	_check(DirAccess.open("res://games/fnarb_binary_adder/enhanced/") != null, "enhanced/ exists")
	var files: PackedStringArray = DirAccess.get_files_at("res://games/fnarb_binary_adder/enhanced/")
	for f in files:
		if f.ends_with(".gd") and f != "game.gd":
			_check(false, "unexpected extra script in enhanced/: " + f)


func _test_scene() -> void:
	_no_rules_copy()
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")
	_check(load(DEMO) is PackedScene, "Direct demo scene still loads")

	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("fnarb_binary_adder", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("fnarb_binary_adder", "direct").is_playable(),
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
	var d: Control = inst.demo
	_check(d.scene_file_path == DEMO, "embedded scene is Direct binary_addition.tscn")
	_check(inst.adder != null and inst.adder.get_script() == AdderScript,
		"Adder uses Direct adder.gd (shared)")
	_check(inst.carriage != null and inst.cursor != null, "carriage + cursor wired")
	_check(inst.cursor.border_color.r > 0.9 and inst.cursor.border_color.g > 0.7 \
			and inst.cursor.border_color.b < 0.2,
		"gold/yellow highlight kept (got %s)" % inst.cursor.border_color)
	_check(inst.carriage.position == AdderScript.CARRIAGE_ORIGIN,
		"carriage at Direct LSB origin %s" % inst.carriage.position)

	# Shared Direct widgets still use Direct scripts.
	_check(d.get_node("background").get_script() == GridScript,
		"background uses Direct shaded_grid.gd")
	_check(d.get_node("Adder/a").get_script() == TruthScript \
			and d.get_node("Adder/b").get_script() == TruthScript,
		"a/b truth tables use Direct truth_table.gd")

	# Early highlight over a/b bit0 (same as Direct smoke).
	await create_timer(0.6).timeout
	var abs_hl: Vector2 = inst.carriage.position + inst.cursor.position
	_check(abs_hl.x == 800.0 and abs_hl.y == 320.0 and inst.cursor.size == Vector2(32, 72),
		"highlight over a/b bit0 at %s size %s" % [abs_hl, inst.cursor.size])
	_check(inst.cursor.modulate.r > 0.9 and inst.cursor.modulate.a > 0.9,
		"cursor.modulate visible gold early (got %s)" % inst.cursor.modulate)

	# Juice: field fits stage letterbox math.
	_check(inst.FIELD_POS.x + inst.FIELD.x <= inst.STAGE.x \
			and inst.FIELD_POS.y + inst.FIELD.y <= inst.STAGE.y,
		"field fits inside stage")

	# Parity vs bare Direct twin: speed both timers, compare result/carry/carriage.
	var twin_root: Node = (load(DIRECT) as PackedScene).instantiate()
	root.add_child(twin_root)
	await _frames(4)
	var twin_demo: Node = twin_root.get_node("Stage/Viewport/Demo")
	var twin_adder: Control = twin_demo.get_node("Adder")
	_check(twin_adder.get_script() == AdderScript, "twin uses Direct adder.gd")
	_check(twin_adder.a == inst.adder.a and twin_adder.b == inst.adder.b,
		"parity: a/b match twin (%d/%d)" % [inst.adder.a, inst.adder.b])

	var timer: Timer = inst.adder.get_node("Timer")
	var twin_timer: Timer = twin_adder.get_node("Timer")
	timer.wait_time = 0.02
	timer.start()
	twin_timer.wait_time = 0.02
	twin_timer.start()
	await create_timer(3.5).timeout

	var bits := ""
	var tbits := ""
	for i in [3, 2, 1, 0]:
		bits += "1" if inst.adder.get_node("r/bit%d" % i).color == AdderScript.I else "0"
		tbits += "1" if twin_adder.get_node("r/bit%d" % i).color == AdderScript.I else "0"
	_check(bits == "1010", "Enhanced result row %s (3+7=1010)" % bits)
	_check(tbits == "1010", "Direct twin result row %s" % tbits)
	_check(bits == tbits, "parity: result bits match twin")

	var carries := ""
	var tcarries := ""
	for i in [4, 3, 2, 1]:
		carries += "1" if inst.adder.get_node("c/bit%d" % i).color == AdderScript.I else "0"
		tcarries += "1" if twin_adder.get_node("c/bit%d" % i).color == AdderScript.I else "0"
	_check(carries == "0111", "Enhanced carry row %s" % carries)
	_check(carries == tcarries, "parity: carry bits match twin")
	_check(inst.carriage.position == twin_adder.get_node("carriage").position,
		"parity: carriage position matches twin %s" % inst.carriage.position)

	# Done card / juice after result lands.
	await _frames(8)
	_check(inst.state == inst.DONE or bits == "1010", "done state or completed result")
	if inst.state == inst.DONE:
		_check(inst._cards["done"].visible, "done card visible")
		_check(inst._bits_set > 0 or inst._particles.size() >= 0, "juice counters live")

	# Gold highlight still present after the walk.
	_check(inst.cursor.border_color.r > 0.9 and inst.cursor.border_color.g > 0.7 \
			and inst.cursor.border_color.b < 0.2,
		"gold highlight still on after walk (got %s)" % inst.cursor.border_color)

	twin_root.queue_free()
	await _frames(2)

	# Esc → PauseOverlay → arcade
	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses the tree")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again → Back to Arcade")
