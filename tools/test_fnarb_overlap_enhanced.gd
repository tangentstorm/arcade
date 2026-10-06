extends SceneTree
## Headless checks for Fnarb Overlap Enhanced (presentation over Direct demo).
## Run: godot --headless --path . --script res://tools/test_fnarb_overlap_enhanced.gd

const SCENE := "res://games/fnarb_overlap/enhanced/game.tscn"
const DIRECT := "res://games/fnarb_overlap/direct/game.tscn"
const DEMO := "res://games/fnarb_overlap/direct/overlap_demo.tscn"
const DemoScript := preload("res://games/fnarb_overlap/direct/overlap_demo.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: fnarb_overlap_enhanced ", msg)
	else:
		print("SMOKE FAIL: fnarb_overlap_enhanced ", msg)
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
	print("fnarb_overlap_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _no_rules_copy() -> void:
	## Enhanced scripts must not redefine Direct overlap helpers.
	var src := FileAccess.get_file_as_string("res://games/fnarb_overlap/enhanced/game.gd")
	_check(src.contains("preload(\"res://games/fnarb_overlap/direct/overlap_demo.tscn\")") \
			or src.contains("preload('res://games/fnarb_overlap/direct/overlap_demo.tscn')"),
		"preloads Direct overlap_demo.tscn")
	_check(not src.contains("func colorize_overlaps"), "no colorize_overlaps rules copy")
	_check(not src.contains("func on_mouse_enter"), "no on_mouse_enter rules copy")
	_check(not src.contains("func on_mouse_leave"), "no on_mouse_leave rules copy")
	_check(not src.contains("for y in range(0, 3)"), "no box-spawn loop copy")
	_check(DirAccess.open("res://games/fnarb_overlap/enhanced/") != null, "enhanced/ exists")
	var files: PackedStringArray = DirAccess.get_files_at("res://games/fnarb_overlap/enhanced/")
	for f in files:
		if f.ends_with(".gd") and f != "game.gd":
			_check(false, "unexpected extra script in enhanced/: " + f)


func _test_scene() -> void:
	_no_rules_copy()
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")
	_check(load(DEMO) is PackedScene, "Direct demo scene still loads")

	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("fnarb_overlap", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("fnarb_overlap", "direct").is_playable(),
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
	# Start button also FOCUS_NONE.
	for b2 in inst._ui.find_children("*", "Button", true, false):
		if b2.text == "Start":
			_check(b2.focus_mode == Control.FOCUS_NONE, "Start FOCUS_NONE")

	# Space → play: Direct demo instanced with Direct script.
	root.push_input(_key(KEY_SPACE))
	await _frames(10)
	_check(inst.state == inst.PLAY and inst.demo != null, "Space begins and loads Direct demo")
	_check(not inst._cards["title"].visible and inst._hud.visible, "title hidden, HUD shown")
	_check(inst._vp_box.visible, "demo viewport visible")
	var d: ColorRect = inst.demo
	_check(d.scene_file_path == DEMO, "embedded scene is Direct overlap_demo.tscn")
	_check(d.get_script() == DemoScript, "demo uses Direct overlap_demo.gd (shared)")
	_check(d.boxes.size() == 9 and d.boxes[1].position == Vector2(125, 50),
		"3×3 boxes, row-major (Direct layout)")
	_check(d.has_node("mouseXY"), "Direct mouseXY label present")

	# Field fits stage letterbox math.
	_check(inst.FIELD_POS.x + inst.FIELD.x <= inst.STAGE.x \
			and inst.FIELD_POS.y + inst.FIELD.y <= inst.STAGE.y,
		"field fits inside stage")

	# Direct demo stays native 1920×1080 @½ — stretch must stay false so VP size holds.
	_check(inst._viewport.size == Vector2i(1920, 1080),
		"SubViewport stays 1920×1080 (not stretched down to field)")
	_check(inst._vp_box.stretch == false, "DemoView.stretch is false")
	_check(inst._vp_box.size == inst.VP_SIZE, "DemoView size is VP_SIZE (1920×1080)")
	var sc: Vector2 = inst._vp_box.scale
	_check(is_equal_approx(sc.x, 0.5) and is_equal_approx(sc.y, 0.5),
		"DemoView scaled to FIELD/VP_SIZE (½)")
	_check(inst._fx != null and is_instance_valid(inst._fx), "Fx juice layer exists")
	_check(inst._fx.get_parent() == inst, "Fx is a child of the enhanced root")
	var fx_i: int = inst._fx.get_index()
	var host_i: int = inst.get_node("StageHost").get_index()
	_check(fx_i > host_i, "Fx draws above StageHost/Direct SubViewport (index %d > %d)" % [fx_i, host_i])
	# Juice anchors match the real half-scale draw position.
	var b0: ColorRect = d.boxes[0] as ColorRect
	var real: Vector2 = inst.FIELD_POS + b0.position * (inst.FIELD / Vector2(inst._viewport.size))
	_check(real.distance_to(inst._box_stage_pos(b0)) < 0.5,
		"juice _box_stage_pos matches half-scale field mapping")

	# Parity vs bare Direct twin: same script, same 9 boxes / positions / colours.
	var twin_root: Node = (load(DIRECT) as PackedScene).instantiate()
	root.add_child(twin_root)
	await _frames(4)
	var twin_demo: ColorRect = twin_root.get_node("Stage/Viewport/Demo") as ColorRect
	_check(twin_demo.get_script() == DemoScript, "twin uses Direct overlap_demo.gd")
	_check(twin_demo.boxes.size() == 9, "twin has 9 boxes")
	var pos_mismatch := 0
	var col_mismatch := 0
	for i in 9:
		var eb: ColorRect = d.boxes[i] as ColorRect
		var tb: ColorRect = twin_demo.boxes[i] as ColorRect
		if eb.position != tb.position or eb.size != tb.size:
			pos_mismatch += 1
		if eb.color != tb.color:
			col_mismatch += 1
	_check(pos_mismatch == 0, "parity: all 9 box positions/sizes match Direct twin")
	_check(col_mismatch == 0, "parity: all 9 box colours match Direct twin (idle white)")

	# Drive Direct hover / press / drag through the shared script (same as Direct smoke).
	d.on_mouse_enter(d.boxes[0])
	_check(d.subject == d.boxes[0] and d.boxes[0].color == Color.CORNFLOWER_BLUE,
		"hover highlights via Direct on_mouse_enter")
	await _frames(2)
	_check(inst._particles.size() > 0 or inst._floaters.size() > 0 or inst._drag_bursts > 0,
		"juice reacts to hover colour change")

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(60, 60)
	d._input(press)
	_check(d.boxes[0].color == Color.GOLDENROD and d.offset == Vector2(-10, -10),
		"press → goldenrod, grab offset (Direct)")
	await _frames(2)

	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(120, 60)
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	d._input(mv)
	_check(d.subject.position == Vector2(110, 50), "drag moves the box (Direct)")
	_check(d.subject.color == Color.BLACK and d.boxes[1].color == Color.DIM_GRAY,
		"overlapping held box → black, other → dim gray (Direct)")
	await _frames(3)
	_check(inst._overlap_count >= 2, "HUD overlap count reflects Direct greys (%d)" % inst._overlap_count)
	_check(inst._first_overlap or inst._banner_t > 0.0 or inst._particles.size() > 0,
		"juice fired on first overlap")
	# Subject HUD stays readable when held+overlap paints the box black.
	var sub_col: Color = inst._subject_label.get_theme_color("font_color")
	_check(sub_col.r + sub_col.g + sub_col.b > 1.2,
		"HUD subject colour stays readable when held (sum=%.2f)" % (sub_col.r + sub_col.g + sub_col.b))

	# Twin still matches script identity after Enhanced watched the drive.
	_check(d.get_script() == twin_demo.get_script() and d.get_script() == DemoScript,
		"parity: Enhanced demo still Direct script after interaction")

	twin_root.queue_free()
	await _frames(2)

	# R reloads Direct demo.
	var old_demo = inst.demo
	root.push_input(_key(KEY_R))
	await _frames(8)
	_check(inst.state == inst.PLAY and inst.demo != null and inst.demo != old_demo,
		"R reloads a fresh Direct demo")
	_check(inst.demo.boxes.size() == 9 and inst.demo.boxes[0].position == Vector2(50, 50),
		"reloaded boxes at Direct origin layout")
	_check(inst.demo.get_script() == DemoScript, "reloaded demo still Direct script")

	# Esc → PauseOverlay → arcade
	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses the tree")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again → Back to Arcade")
