extends SceneTree
## Headless checks for Overlap Demo Enhanced (presentation over the Direct scene).
## Run: godot --headless --path . --script res://tools/test_overlap_demo_enhanced.gd

const SCENE := "res://games/overlap_demo/enhanced/game.tscn"
const DIRECT := "res://games/overlap_demo/direct/game.tscn"
const DirectScript := preload("res://games/overlap_demo/direct/game.gd")
const Logic := preload("res://games/overlap_demo/direct/overlap_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: overlap_demo_enhanced ", msg)
	else:
		print("SMOKE FAIL: overlap_demo_enhanced ", msg)
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
	print("overlap_demo_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _no_rules_copy() -> void:
	var src := FileAccess.get_file_as_string("res://games/overlap_demo/enhanced/game.gd")
	_check(src.contains("preload(\"res://games/overlap_demo/direct/game.tscn\")"),
		"preloads Direct game.tscn")
	for needle in ["func step", "func overlaps", "func contains_point", "func mouse_pressed",
			"func mouse_dragged", "func mouse_released", "75 * i + 50", "class Square"]:
		_check(not src.contains(needle), "no rules copy: '%s' absent" % needle)
	var files: PackedStringArray = DirAccess.get_files_at("res://games/overlap_demo/enhanced/")
	for f in files:
		if f.ends_with(".gd") and f != "game.gd":
			_check(false, "unexpected extra script in enhanced/: " + f)


## Sketch pixel → window (root viewport) coordinates. Aim at the pixel's interior
## (+¼ px) so Direct's floori() never lands on a float-rounded boundary.
func _to_screen(inst: Node2D, sketch: Vector2) -> Vector2:
	return inst.get_global_transform_with_canvas() * inst.sketch_to_stage(sketch + Vector2(0.25, 0.25))


func _mouse(inst: Node2D, sketch: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ev.position = _to_screen(inst, sketch)
	ev.global_position = ev.position
	root.push_input(ev)


func _motion(inst: Node2D, sketch: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = _to_screen(inst, sketch)
	mv.global_position = mv.position
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mv)


func _test_scene() -> void:
	_no_rules_copy()
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")

	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("overlap_demo", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("overlap_demo", "direct").is_playable(), "registry: direct still playable")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(not inst._hud.visible, "HUD hidden behind the title card")
	_check(inst.STAGE == Vector2(1280, 720), "1280×720 stage")
	_check(inst.FIELD == Vector2(600, 600), "600×600 field (300×300 @2×)")
	_check(inst.FIELD_POS.x >= 0 and inst.FIELD_POS.y >= 0 \
			and inst.FIELD_POS.x + inst.FIELD.x <= inst.STAGE.x \
			and inst.FIELD_POS.y + inst.FIELD.y <= inst.STAGE.y, "field fits inside stage")

	# Buttons: Start + Back on the title card, Back in the HUD, all FOCUS_NONE.
	var starts := 0
	var backs := 0
	for b in inst._ui.find_children("*", "Button", true, false):
		_check(b.focus_mode == Control.FOCUS_NONE, "%s FOCUS_NONE (%s)" % [b.text, b.get_path()])
		if b.text == "Start":
			starts += 1
		elif b.text == "Back to Arcade":
			backs += 1
	_check(starts == 1, "one Start button")
	_check(backs >= 2, "Back to Arcade on title card and HUD (%d)" % backs)

	# Direct is instanced (frozen) behind the title.
	var d: Control = inst.direct
	_check(d != null and d.scene_file_path == DIRECT, "embedded scene is Direct game.tscn")
	_check(d.get_script() == DirectScript, "embedded uses Direct game.gd (shared)")
	_check(d.world.get_script() == Logic, "world is Direct overlap_logic.gd")
	_check(d.process_mode == Node.PROCESS_MODE_DISABLED, "Direct frozen behind title card")
	_check(not d.get_node("Help").visible, "Direct margin hint hidden (Enhanced HUD replaces it)")

	# SubViewport: native 300×300, stretch=false + 2× scale.
	_check(inst._viewport.size == Vector2i(300, 300), "SubViewport stays native 300×300")
	_check(inst._vp_box.stretch == false, "DemoView.stretch is false")
	_check(inst._vp_box.size == inst.VP_SIZE, "DemoView size is VP_SIZE (300×300)")
	_check(inst._vp_box.scale == Vector2(2, 2), "DemoView scaled 2× (FIELD / VP_SIZE)")
	var room: Control = d.get_node("%Room")
	_check(room.scale == Vector2.ONE and room.position == Vector2.ZERO,
		"Direct room fits the VP 1:1 (scale %s, pos %s)" % [room.scale, room.position])
	_check(inst._fx != null and inst._fx.get_parent() == inst, "Fx juice layer is a child of the root")
	var fx_i: int = inst._fx.get_index()
	var host_i: int = inst._stage_host.get_index()
	_check(fx_i > host_i, "Fx draws above StageHost/Direct SubViewport (index %d > %d)" % [fx_i, host_i])
	var p := Vector2(137, 61)
	var real: Vector2 = inst.FIELD_POS + inst._vp_box.scale * p
	_check(real.distance_to(inst.sketch_to_stage(p)) < 0.01, "juice mapping matches the 2× field")

	# Clicks on the field while the title card is up don't reach Direct.
	_mouse(inst, Vector2(137, 137), true)
	await _frames(2)
	_mouse(inst, Vector2(137, 137), false)
	await _frames(1)
	_check(d.world.in_hand == null and d._buttons == 0, "title card blocks field clicks")

	# Space → play.
	root.push_input(_key(KEY_SPACE))
	await _frames(4)
	_check(inst.state == inst.PLAY and not inst._cards["title"].visible and inst._hud.visible,
		"Space starts: title hidden, HUD shown")
	_check(d.process_mode == Node.PROCESS_MODE_INHERIT, "Direct unfrozen on start")

	# Bare logic twin to replay the same Processing events for parity.
	var twin = Logic.new()

	# Real mouse through the Enhanced stage → SubViewport → Direct game.gd → sketch coords.
	_mouse(inst, Vector2(137, 137), true)
	twin.mouse_pressed(137, 137)
	await _frames(2)
	_check(d.world.in_hand == d.world.squares[4], "stage click at sketch (137,137) grabs the centre square")
	_motion(inst, Vector2(200, 140))
	twin.mouse_dragged(200, 140)
	await _frames(4)
	twin.step()
	_check(absf(d.world.squares[4].x - 188) <= 1.0 and absf(d.world.squares[4].y - 128) <= 1.0,
		"drag moves it in sketch px (%s, %s)" % [d.world.squares[4].x, d.world.squares[4].y])
	_check(d.world.squares[4].fill_color == Logic.GRAY and d.world.squares[7].fill_color == Logic.GRAY,
		"Direct grays the overlapping pair (4, 7)")
	_check(inst._gray_count == 2 and inst._pair_count == 1,
		"HUD reads 2 gray / 1 zone (%d / %d)" % [inst._gray_count, inst._pair_count])
	_check(inst._grabs == 1 and inst._prev_held == 4, "grab observed (#4)")
	_check(inst._overlap_events == 2 and inst._first_overlap, "overlap juice fired for both squares")
	_check(inst._particles.size() > 0 and inst._rings.size() > 0, "bursts + rings spawned")
	inst._shake = 1.0
	await _frames(1)
	_check(inst._vp_box.position == inst.FIELD_POS and inst._fx.position == Vector2.ZERO,
		"shake juice never moves the SubViewport / Fx (input mapping stays exact)")
	_check(inst._held_label.text.begins_with("held  #4"), "HUD shows held #4 (%s)" % inst._held_label.text)
	_check(inst._gray_label.text == "GRAY  2 / 9", "HUD gray label (%s)" % inst._gray_label.text)

	var mism := 0
	for i in 9:
		var a = d.world.squares[i]
		var b = twin.squares[i]
		if a.x != b.x or a.y != b.y or a.fill_color != b.fill_color:
			mism += 1
	_check(mism == 0, "parity: all 9 squares match a bare Direct logic twin")
	_check(str(d.world.render()) == str(twin.render()), "parity: render list matches the twin")

	_mouse(inst, Vector2(200, 140), false)
	twin.mouse_released(200, 140)
	await _frames(3)
	_check(d.world.in_hand == null and inst._prev_held == -1, "release drops the square")

	# Drag square 0 off the canvas → lost-square juice.
	_mouse(inst, Vector2(62, 62), true)
	twin.mouse_pressed(62, 62)
	await _frames(2)
	_check(d.world.in_hand == d.world.squares[0], "grab square 0")
	_motion(inst, Vector2(-100, 62))
	twin.mouse_dragged(-100, 62)
	await _frames(4)
	_mouse(inst, Vector2(-100, 62), false)
	twin.mouse_released(-100, 62)
	await _frames(3)
	twin.step()
	_check(d.world.squares[0].x < -50, "square 0 dragged off canvas (x=%s)" % d.world.squares[0].x)
	_check(inst._lost_count == 1, "HUD counts 1 off-canvas square")
	var lost_floater := false
	for f in inst._floaters:
		if f.text == "LOST":
			lost_floater = true
	_check(lost_floater, "LOST floater fired")
	mism = 0
	for i in 9:
		var a = d.world.squares[i]
		var b = twin.squares[i]
		if a.x != b.x or a.y != b.y or a.fill_color != b.fill_color:
			mism += 1
	_check(mism == 0, "parity after off-canvas drag (%s,%s vs %s,%s)" % [d.world.squares[0].x, d.world.squares[0].y, twin.squares[0].x, twin.squares[0].y])

	# Clearing the overlap (drag 4 back) fires clear juice; Direct whitens both.
	d.world.mouse_pressed(195, 135)
	d.world.mouse_dragged(132, 132)
	d.world.mouse_released(132, 132)
	await _frames(4)
	_check(d.world.squares[4].fill_color == Logic.WHITE and d.world.squares[7].fill_color == Logic.WHITE,
		"Direct whitens the separated pair")
	_check(inst._clear_events >= 2 and inst._gray_count == 0, "clear juice + HUD back to 0 gray")

	# R resets: fresh Direct with the original layout.
	var old = inst.direct
	root.push_input(_key(KEY_R))
	await _frames(4)
	_check(inst.direct != null and inst.direct != old, "R reloads a fresh Direct scene")
	_check(inst.direct.world.squares[0].x == 50 and inst.direct.world.squares[4].x == 125,
		"reset squares at the Direct grid layout")
	_check(inst._grabs == 0 and inst._lost_count == 0, "reset clears HUD counters")
	_check(inst.direct.process_mode == Node.PROCESS_MODE_INHERIT, "reset demo is live")

	# Esc → PauseOverlay → arcade.
	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses the tree")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again → Back to Arcade")
