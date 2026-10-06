extends SceneTree
## Headless checks for GodotLab Game 00 Enhanced (presentation over the Direct drift sprite).
## Run: godot --headless --path . --script res://tools/test_godotlab_game00_enhanced.gd

const SCENE := "res://games/godotlab_game00/enhanced/game.tscn"
const DIRECT := "res://games/godotlab_game00/direct/game.tscn"
const IconScript := preload("res://games/godotlab_game00/direct/icon.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: godotlab_game00_enhanced ", msg)
	else:
		print("SMOKE FAIL: godotlab_game00_enhanced ", msg)
		_fail += 1


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _hold(code: Key, down: bool) -> void:
	var ev := _key(code, down)
	# Match Direct test_godotlab.gd: icon.gd reads Input action state.
	Input.parse_input_event(ev)
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
	print("godotlab_game00_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _no_rules_copy() -> void:
	var src := FileAccess.get_file_as_string("res://games/godotlab_game00/enhanced/game.gd")
	_check(src.contains("preload(\"res://games/godotlab_game00/direct/game.tscn\")"),
		"preloads Direct game.tscn")
	_check(not src.contains("const SPEED") and not src.contains("friction = 0.975"),
		"no SPEED / friction copy (physics stay Direct)")
	_check(not src.contains("velocity *= friction") and not src.contains("velocity += R * SPEED"),
		"no impulse / friction step copy")
	_check(src.contains("stretch = false") and src.contains("VIEW_K"),
		"SubViewport uses stretch=false + scale (not stretch=true)")
	_check(not src.contains("stretch = true"), "does not set stretch=true")
	var files: PackedStringArray = DirAccess.get_files_at("res://games/godotlab_game00/enhanced/")
	for f in files:
		if f.ends_with(".gd") and f != "game.gd":
			_check(false, "unexpected extra script in enhanced/: " + f)


## Drive a bare Direct twin with the same arrow holds; returns [pos, vel] after frames.
func _twin_drive(hold_code: Key, frames: int) -> Array:
	var twin: Node = (load(DIRECT) as PackedScene).instantiate()
	root.add_child(twin)
	var ic: Sprite2D = twin.get_node("icon")
	ic.wrap = false
	await _physics(2)
	_hold(hold_code, true)
	await _physics(frames)
	_hold(hold_code, false)
	var out := [ic.position, ic.velocity]
	twin.queue_free()
	await _frames(2)
	# Clear any lingering action state.
	_hold(hold_code, false)
	return out


func _test_scene() -> void:
	_no_rules_copy()
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")

	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("godotlab_game00", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("godotlab_game00", "direct").is_playable(), "registry: direct still playable")

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
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			backs += 1
			_check(b.focus_mode == Control.FOCUS_NONE, "Back to Arcade FOCUS_NONE (%s)" % b.get_path())
		elif b.focus_mode != Control.FOCUS_NONE:
			_check(false, "button %s FOCUS_NONE" % b.text)
	_check(backs >= 2, "Back to Arcade on title card + HUD (%d)" % backs)

	_tap(KEY_SPACE)
	await _frames(4)
	_check(inst.state == inst.PLAY, "Space starts")
	_check(not inst._cards["title"].visible and inst._hud.visible and inst._clip.visible,
		"title hidden, HUD + field shown")
	var d: Node2D = inst.demo
	_check(d.scene_file_path == DIRECT, "game is Direct game.tscn")
	var ic: Sprite2D = inst.icon
	_check(ic != null and ic.get_script() == IconScript, "icon is Direct icon.gd")
	_check(not d.get_node("Hud").visible, "Direct plain HUD hidden (Enhanced draws its own)")
	_check(inst._viewport.size == Vector2i(1280, 720), "Direct in native 1280×720 SubViewport")
	_check(inst._vp_box.stretch == false, "SubViewportContainer.stretch is false")
	_check(inst._vp_box.scale == Vector2(0.75, 0.75), "SubViewportContainer scaled to 0.75")
	_check(inst._clip.clip_contents, "field is clipped")
	_check(ic.position == Vector2(438, 246), "Direct spawn position (438, 246)")

	# Framing: icon centre maps inside the field.
	var field := Rect2(inst.FIELD_POS, inst.FIELD)
	var stage_p: Vector2 = inst.icon_stage_pos()
	_check(field.has_point(stage_p), "icon stage pos inside the field (%s)" % stage_p)
	_check(field.end.x <= 1280 and field.end.y <= 720, "field fits the stage")
	_check(is_equal_approx(inst.icon_stage_r(), 48.0), "icon stage radius 64×0.75 = 48")

	# Parity: Enhanced Direct icon vs a bare Direct twin under the same right-hold.
	ic.wrap = false
	await _physics(2)
	var x0: float = ic.position.x
	_hold(KEY_RIGHT, true)
	await _physics(10)
	_hold(KEY_RIGHT, false)
	_check(ic.velocity.x > 300.0, "Enhanced → builds velocity (vx=%.0f)" % ic.velocity.x)
	_check(ic.position.x > x0 + 20.0, "Enhanced → moves the sprite (dx=%.0f)" % (ic.position.x - x0))
	_check(inst.boosts >= 1 and inst.thrusts >= 1, "thrust / boost juice while holding →")
	_check(inst._trail.size() >= 2, "motion trail samples while moving")
	_check(inst.peak_speed > 300.0, "peak speed tracked")
	var enh_pos: Vector2 = ic.position
	var enh_vel: Vector2 = ic.velocity

	# Coast on Enhanced (still the only listener).
	await _physics(240)
	_check(absf(ic.velocity.x) < 10.0, "Enhanced friction coasts to a stop (vx=%.1f)" % ic.velocity.x)
	_check(inst.distance > 50.0, "distance accumulates while sliding (%.0f)" % inst.distance)

	# Twin replay: freeze Enhanced's Direct icon so shared Input only drives the twin.
	ic.set_physics_process(false)
	var twin := await _twin_drive(KEY_RIGHT, 10)
	_check(twin[0].distance_to(enh_pos) < 0.5,
		"parity: twin position after 10→ frames matches Enhanced (twin %s enh %s)" % [twin[0], enh_pos])
	_check(absf(twin[1].x - enh_vel.x) < 1.0 and absf(twin[1].y - enh_vel.y) < 1.0,
		"parity: twin velocity matches Enhanced at release (twin %s enh %s)" % [twin[1], enh_vel])
	ic.set_physics_process(true)

	# Wrap juice: fling past the left edge inside the SubViewport.
	ic.wrap = true
	ic.velocity = Vector2.ZERO
	ic.position = Vector2(-5, 200)
	var wraps0: int = inst.wraps
	await _physics(2)
	_check(ic.position.x > 1000.0, "Enhanced wraps at the SubViewport edge (x=%.0f)" % ic.position.x)
	_check(inst.wraps > wraps0, "wrap counter increments")
	_check(inst._flash > 0.0 or inst._banner == "WRAP", "wrap juice (flash / banner)")

	# Soft reset keeps the same Direct instance.
	var same: Sprite2D = ic
	_tap(KEY_R)
	await _frames(2)
	_check(inst.icon == same and inst.demo == d, "R keeps the same Direct scene")
	_check(ic.position == Vector2(438, 246) and ic.velocity == Vector2.ZERO, "R resets spawn")
	_check(inst.wraps == 0 and inst.distance == 0.0, "R clears telemetry")

	# HUD labels track Direct state.
	_hold(KEY_UP, true)
	await _physics(5)
	_hold(KEY_UP, false)
	_check(inst._speed_label.text.contains("speed") and inst._pos_label.text.contains("pos"),
		"HUD telemetry labels present")
	_check(ic.velocity.y < -50.0, "↑ builds upward velocity via Direct")

	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again → Back to Arcade")
