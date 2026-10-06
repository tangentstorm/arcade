extends SceneTree
## Headless checks for Bullet Demo Enhanced (presentation over Direct game.tscn).
## Run: godot --headless --path . --script res://tools/test_bullet_demo_enhanced.gd

const SCENE := "res://games/bullet_demo/enhanced/game.tscn"
const DIRECT := "res://games/bullet_demo/direct/game.tscn"
const Logic := preload("res://games/bullet_demo/direct/bullet_logic.gd")

var _fail := 0
var _ok := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("ok: bullet_demo_enhanced ", msg)
	else:
		print("SMOKE FAIL: bullet_demo_enhanced ", msg)
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
	_no_rules_copy()
	await _test_scene()
	print("bullet_demo_enhanced: %s (%d checks)" % [
		"all ok" if _fail == 0 else "%d failure(s)" % _fail, _ok + _fail])
	quit(1 if _fail else 0)


func _no_rules_copy() -> void:
	var src := FileAccess.get_file_as_string("res://games/bullet_demo/enhanced/game.gd")
	_check(src.contains('preload("res://games/bullet_demo/direct/game.tscn")'),
		"preloads Direct game.tscn")
	_check(src.contains('preload("res://games/bullet_demo/direct/bullet_logic.gd")'),
		"preloads Direct bullet_logic.gd (for constants / typing)")
	_check(not src.contains("class Box") and not src.contains("func bullet_update")
			and not src.contains("func overlaps(") and not src.contains("K_BULLET_SPEED :="),
		"no Box / overlap / speed rules copy")
	_check(not src.contains("func step(") and not src.contains("func mouse_pressed("),
		"enhanced defines no step / mouse_pressed rules")
	_check(src.contains("stretch = false") and src.contains("VIEW_K"),
		"SubViewport uses stretch=false + scale (not stretch=true)")
	_check(not src.contains("stretch = true"), "does not set stretch=true")
	# Denial comment "No Alchementrix IP" is required; do not treat it as a brand use.
	var files: PackedStringArray = DirAccess.get_files_at("res://games/bullet_demo/enhanced/")
	for f in files:
		if f.ends_with(".gd") and f != "game.gd":
			_check(false, "unexpected extra script in enhanced/: " + f)


func _snapshot(w) -> Array:
	var out: Array = [w.bullets_left]
	for sq in w.squares:
		out.append([sq.x, sq.y, sq.alive])
	for b in w.bullets:
		out.append([b.x, b.y, b.alive])
	out.append(w.render())
	return out


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")

	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("bullet_demo", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("bullet_demo", "direct").is_playable(),
		"registry: direct still playable")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(inst.demo == null and not inst._vp_box.visible, "Direct scene not loaded until Start")
	_check(inst.STAGE == Vector2(1280, 720), "1280×720 stage")
	_check(inst.VP_SIZE == Vector2(300, 300) and inst.FIELD == Vector2(600, 600),
		"Direct 300×300 viewport framed in 600×600 field")
	_check(is_equal_approx(inst.VIEW_K, 2.0), "VIEW_K is 2.0 (stretch=false scale)")

	var backs := 0
	var start_btn: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		_check(b.focus_mode == Control.FOCUS_NONE, "button '%s' FOCUS_NONE" % b.text)
		if b.text == "Back to Arcade":
			backs += 1
		elif b.text == "Start":
			start_btn = b
	_check(backs >= 2, "Back to Arcade on title card + HUD (%d)" % backs)
	_check(start_btn != null, "title has a Start button")

	root.push_input(_key(KEY_SPACE))
	await _frames(6)
	_check(inst.state == inst.PLAY, "Space starts")
	_check(not inst._cards["title"].visible and inst._hud.visible and inst._vp_box.visible,
		"title hidden, HUD + field shown")
	var d: Control = inst.demo
	_check(d != null and d.scene_file_path == DIRECT, "game is Direct game.tscn")
	_check(inst.world != null and inst.world.get_script() == Logic,
		"world is Direct bullet_logic.gd")
	_check(inst._viewport.size == Vector2i(300, 300), "Direct in native 300×300 SubViewport")
	_check(inst._vp_box.stretch == false, "SubViewportContainer.stretch is false")
	_check(inst._vp_box.scale == Vector2(2, 2), "SubViewportContainer scaled to 2.0")
	_check(inst._vp_box.size == inst.VP_SIZE, "TableView size is VP_SIZE")
	_check(inst.FIELD_POS.x + inst.FIELD.x <= inst.STAGE.x
			and inst.FIELD_POS.y + inst.FIELD.y <= inst.STAGE.y,
		"field fits inside stage")
	var help := d.get_node_or_null("Help")
	_check(help == null or not help.visible, "Direct plain Help hidden")
	_check(inst._fx != null and is_instance_valid(inst._fx), "Fx juice layer exists")
	var fx_i: int = inst._fx.get_index()
	var host_i: int = inst.get_node("StageHost").get_index()
	_check(fx_i > host_i, "Fx draws above StageHost/Direct SubViewport")

	# Freeze Direct's auto step so tick() owns the clock for parity.
	d.set_process(false)
	await _frames(2)

	var twin = Logic.new()
	# Reset Enhanced world to a fresh Logic so both start identical.
	inst.world = Logic.new()
	d.world = inst.world
	inst._snap_prev()
	inst._shots = 0
	inst._hits = 0
	inst._fizzles = 0
	inst._dry_clicks = 0
	inst._steps = 0

	var script := [
		[[], 3],
		[[["press", 55, 280]], 1],   # col 0 bottom-ish
		[[], 40],
		[[["press", 130, 280]], 1],  # col 1
		[[], 40],
		[[["press", 205, 280]], 1],  # col 2
		[[], 40],
		[[["press", 10, 280]], 1],   # empty rack → dry (all 3 spent / in flight or racked)
		[[], 90],
	]
	var same := true
	var n := 0
	for seg in script:
		var evs: Array = seg[0]
		for e in evs:
			match String(e[0]):
				"press":
					twin.mouse_pressed(int(e[1]), int(e[2]))
				"release":
					twin.mouse_released(int(e[1]), int(e[2]))
				"drag":
					twin.mouse_dragged(int(e[1]), int(e[2]))
		for i in int(seg[1]):
			inst.tick(evs if i == 0 else [])
			twin.step()
			same = same and _snapshot(twin) == _snapshot(inst.world)
			n += 1
	_check(same, "state/squares/bullets/render list match Direct over %d scripted ticks" % n)
	_check(inst._shots >= 3, "observer: at least 3 shots counted (%d)" % inst._shots)
	_check(inst._hits >= 1, "observer: at least 1 hit counted (%d)" % inst._hits)
	_check(inst._trails.size() == Logic.K_BULLET_COUNT, "trail slots for each bullet")

	# Kill remaining live squares with scripted presses after ammo returns.
	# Wait for rack to refill by stepping until bullets_left > 0, then fire lanes.
	var safety := 0
	while inst.world.bullets_left < 3 and safety < 200:
		inst.tick([])
		twin.step()
		safety += 1
	_check(inst.world.bullets_left == twin.bullets_left, "rack refill parity")

	# Fresh twin pair: clear board → confirm identical render, then fire one lane.
	inst.world = Logic.new()
	d.world = inst.world
	twin = Logic.new()
	inst._snap_prev()
	inst._shots = 0
	inst._hits = 0
	inst._fizzles = 0
	inst.tick([["press", 55, 280]])
	twin.mouse_pressed(55, 280)
	twin.step()
	for _i in 80:
		inst.tick([])
		twin.step()
	_check(_snapshot(twin) == _snapshot(inst.world), "parity after a fresh single-lane fire")
	_check(inst._shots == 1, "one shot on the fresh lane")
	_check(inst._hits >= 1, "hit juice on the fresh lane (%d)" % inst._hits)
	_check(inst._particles.size() > 0 or inst._floaters.size() > 0 or inst._flash > 0.0
			or inst._rings.size() > 0,
		"juice particles/floaters/flash after hit")

	# Aim guide + stage mapping.
	var stage_p: Vector2 = inst.sketch_to_stage(Vector2(150, 150))
	_check(Rect2(inst.FIELD_POS, inst.FIELD).has_point(stage_p),
		"sketch centre maps inside the field (%s)" % stage_p)
	_check(is_equal_approx(stage_p.x, inst.FIELD_POS.x + 300.0),
		"sketch_to_stage uses VIEW_K=2")

	# HUD labels present.
	_check(inst._shots_label.text.contains("shots") and inst._rack_label.text.contains("ammo"),
		"HUD telemetry labels present")

	# Esc → PauseOverlay → arcade
	d.set_process(true)
	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses the tree")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again → Back to Arcade")
