extends SceneTree
## Headless checks for GodotLab Game 01 Enhanced (presentation over the Direct hero + crosshair).
## Run: godot --headless --path . --script res://tools/test_godotlab_game01_enhanced.gd

const SCENE := "res://games/godotlab_game01/enhanced/game.tscn"
const DIRECT := "res://games/godotlab_game01/direct/game.tscn"
const HeroScript := preload("res://games/godotlab_game01/direct/hero.gd")
const CrosshairScript := preload("res://games/godotlab_game01/direct/crosshair.gd")

var _fail := 0
var _pass := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("ok: godotlab_game01_enhanced ", msg)
	else:
		print("SMOKE FAIL: godotlab_game01_enhanced ", msg)
		_fail += 1


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


## Match Direct test_godotlab.gd: hero.gd polls Input key state.
func _hold(code: Key, down: bool) -> void:
	Input.parse_input_event(_key(code, down))
	Input.flush_buffered_events()


func _tap(code: Key) -> void:
	root.push_input(_key(code, true))
	root.push_input(_key(code, false))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_scene()
	print("godotlab_game01_enhanced: %s (%d passed)" % [
		"all ok" if _fail == 0 else "%d failure(s)" % _fail, _pass])
	quit(1 if _fail else 0)


func _no_rules_copy() -> void:
	var src := FileAccess.get_file_as_string("res://games/godotlab_game01/enhanced/game.gd")
	_check(src.contains("preload(\"res://games/godotlab_game01/direct/game.tscn\")"),
		"preloads Direct game.tscn")
	_check(not src.contains("const SPEED") and not src.contains("diff.y -= SPEED"),
		"no SPEED / movement copy (hero.gd stays Direct)")
	_check(not src.contains("is_physical_key_pressed") and not src.contains("oldmouse"),
		"no key polling / mouse-delta copy (crosshair.gd stays Direct)")
	_check(not src.contains("rotation = (position - crosshair.position)"), "no facing rule copy")
	_check(src.contains("stretch = false") and src.contains("VIEW_K"),
		"SubViewport uses stretch=false + scale (not stretch=true)")
	_check(not src.contains("stretch = true"), "does not set stretch=true")
	for f in DirAccess.get_files_at("res://games/godotlab_game01/enhanced/"):
		if f.ends_with(".gd") and f != "game.gd":
			_check(false, "unexpected extra script in enhanced/: " + f)


func _test_scene() -> void:
	_no_rules_copy()
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")

	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("godotlab_game01", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("godotlab_game01", "direct").is_playable(), "registry: direct still playable")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(inst.demo == null and not inst._clip.visible, "Direct scene not loaded until Start")
	_check(inst.STAGE == Vector2(1280, 720), "1280×720 stage")
	_check(inst.VP_SIZE == Vector2(1280, 720) and inst.FIELD == Vector2(960, 540),
		"Direct 1280×720 viewport framed in 960×540 field")
	_check(is_equal_approx(inst.VIEW_K, 0.75), "VIEW_K is 0.75 (stretch=false scale)")

	var backs := 0
	var starts := 0
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			backs += 1
		if b.text == "Start":
			starts += 1
		_check(b.focus_mode == Control.FOCUS_NONE, "%s FOCUS_NONE (%s)" % [b.text, b.get_path()])
	_check(backs >= 2, "Back to Arcade on title card + HUD (%d)" % backs)
	_check(starts == 1, "title card has a Start button")

	_tap(KEY_SPACE)
	await _frames(4)
	_check(inst.state == inst.PLAY, "Space starts")
	_check(not inst._cards["title"].visible and inst._hud.visible and inst._clip.visible,
		"title hidden, HUD + field shown")
	var d: Node2D = inst.demo
	_check(d.scene_file_path == DIRECT, "game is Direct game.tscn")
	var hero: Sprite2D = inst.hero
	var xh: Sprite2D = inst.crosshair
	_check(hero != null and hero.get_script() == HeroScript, "hero is Direct hero.gd")
	_check(xh != null and xh.get_script() == CrosshairScript, "crosshair is Direct crosshair.gd")
	_check(inst.scene_root.scale == Vector2(2, 2), "Direct 2× Scene root kept")
	_check(not d.get_node("Hud").visible, "Direct plain HUD hidden (Enhanced draws its own)")
	_check(inst._viewport.size == Vector2i(1280, 720), "Direct in native 1280×720 SubViewport")
	_check(inst._vp_box.stretch == false, "SubViewportContainer.stretch is false")
	_check(inst._vp_box.scale == Vector2(0.75, 0.75), "SubViewportContainer scaled to 0.75")
	_check(inst._clip.clip_contents, "field is clipped")
	_check(hero.position.is_equal_approx(inst.SPAWN_HERO), "Direct hero spawn position")

	var field := Rect2(inst.FIELD_POS, inst.FIELD)
	_check(field.has_point(inst.hero_stage_pos()) and field.has_point(inst.crosshair_stage_pos()),
		"hero + crosshair map inside the field")
	_check(field.end.x <= 1280 and field.end.y <= 720, "field fits the stage")
	_check(is_equal_approx(inst.hero_stage_r(), 17.0 * 2.0 * 0.75), "hero stage radius 17×2×0.75")
	_check(inst.hero_stage_pos().is_equal_approx(inst.FIELD_POS + hero.global_position * 0.75),
		"stage mapping = FIELD_POS + Direct global × 0.75")

	# Parity: Enhanced's Direct hero vs a bare Direct twin under the same D hold.
	await _physics(2)
	var h0: Vector2 = hero.position
	var c0: Vector2 = xh.position
	_hold(KEY_D, true)
	await _physics(5)
	_hold(KEY_D, false)
	var enh_dh: Vector2 = hero.position - h0
	var enh_dc: Vector2 = xh.position - c0
	_check(is_equal_approx(enh_dh.x, 50.0) and is_zero_approx(enh_dh.y),
		"Enhanced D moves 10 px/frame via Direct (dx=%.1f)" % enh_dh.x)
	_check(enh_dc.is_equal_approx(enh_dh), "Enhanced crosshair drifts with the hero")
	_check(inst.steps >= 4 and inst.distance >= 40.0, "walk telemetry (%d steps, %.0f px)" % [inst.steps, inst.distance])
	_check(inst._trail.size() >= 2, "dust trail samples while walking")
	_check(inst._particles.size() > 0, "dust / ember particles")
	var enh_rot: float = hero.rotation

	hero.set_physics_process(false)
	var twin: Node = (load(DIRECT) as PackedScene).instantiate()
	root.add_child(twin)
	var th: Sprite2D = twin.get_node("Scene/hero")
	var tc: Sprite2D = twin.get_node("Scene/crosshair")
	await _physics(2)
	var t0: Vector2 = th.position
	var tc0: Vector2 = tc.position
	_hold(KEY_D, true)
	await _physics(5)
	_hold(KEY_D, false)
	_check((th.position - t0).is_equal_approx(enh_dh),
		"parity: twin hero delta matches Enhanced (%s vs %s)" % [th.position - t0, enh_dh])
	_check((tc.position - tc0).is_equal_approx(enh_dc), "parity: twin crosshair drift matches")
	_check(th.position.is_equal_approx(hero.position), "parity: same hero position after D×5")
	_check(is_equal_approx(th.rotation, enh_rot), "parity: same facing (%.3f)" % enh_rot)
	twin.queue_free()
	await _frames(2)
	hero.set_physics_process(true)

	var hu: Vector2 = hero.position
	_hold(KEY_UP, true)
	await _physics(3)
	_hold(KEY_UP, false)
	_check(hero.position.y <= hu.y - 10.0 and is_equal_approx(hero.position.x, hu.x), "↑ moves up via Direct (dy=%.0f)" % (hero.position.y - hu.y))

	# Facing: crosshair straight above the hero → nose points up; HUD reads N.
	xh.position = hero.position + Vector2(0, -60)
	await _physics(2)
	await _frames(1)
	_check(absf(wrapf(hero.rotation - PI / 2, -PI, PI)) < 0.01, "Direct hero turns to face the crosshair")
	_check(inst.nose_dir().is_equal_approx(Vector2.UP), "nose_dir follows Direct rotation")
	_check(inst._face_label.text.contains("N") and inst._face_label.text.contains("000"),
		"HUD facing reads 000° N (%s)" % inst._face_label.text)
	_check(inst._aim_label.text.contains("60"), "HUD aim range 60 px (%s)" % inst._aim_label.text)
	# Snap turn juice: crosshair flips below the hero.
	var turns0: int = inst.turns
	xh.position = hero.position + Vector2(0, 60)
	await _physics(2)
	await _frames(2)
	_check(inst.turns > turns0, "snap turn counted")

	# Mouse mapping: Direct crosshair.gd reads get_parent().get_local_mouse_position()
	# inside the SubViewport. With stretch=false + 0.75 scale, that must equal the
	# stage mouse mapped back into Direct window space, then into the 2× Scene.
	# (Headless has no real pointer, so check the transform chain at the current point.)
	var stage_m: Vector2 = inst.get_local_mouse_position()
	var vp_m: Vector2 = inst._viewport.get_mouse_position()
	_check(vp_m.distance_to(inst.stage_to_vp(stage_m)) < 0.01,
		"SubViewport mouse = (stage − FIELD_POS) / 0.75 (%s vs %s)" % [vp_m, inst.stage_to_vp(stage_m)])
	_check(xh._mouse().distance_to(inst.scene_root.get_global_transform().affine_inverse() * vp_m) < 0.01,
		"Direct crosshair._mouse() sees the scaled SubViewport point")
	_check(inst._vp_box.mouse_filter != Control.MOUSE_FILTER_IGNORE, "field passes mouse events to Direct")
	# A crosshair move (as Direct would apply from a mouse delta) maps 1:1 into stage space.
	var cs0: Vector2 = inst.crosshair_stage_pos()
	xh.position += Vector2(40, 20)
	_check((inst.crosshair_stage_pos() - cs0).is_equal_approx(Vector2(40, 20) * 2.0 * 0.75),
		"crosshair overlay tracks Direct position (×2 Scene ×0.75 view)")

	# Off-field locator: walk the hero out of the Direct screen.
	var exits0: int = inst.exits
	hero.position = Vector2(-80, 100)
	await _physics(1)
	await _frames(2)
	_check(not inst.hero_in_field() and inst.exits > exits0, "off-field exit counted")
	_check(inst._banner.contains("OFF-FIELD"), "off-field banner")

	# Soft reset keeps the same Direct instance.
	_tap(KEY_R)
	await _frames(2)
	_check(inst.hero == hero and inst.demo == d, "R keeps the same Direct scene")
	_check(hero.position.is_equal_approx(inst.SPAWN_HERO) and xh.position.is_equal_approx(inst.SPAWN_XHAIR),
		"R resets Direct spawn positions")
	_check(inst.distance == 0.0 and inst.exits == 0, "R clears telemetry")
	_check(inst.hero_in_field(), "hero back in field after R")

	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again → Back to Arcade")
