extends SceneTree
## Headless checks for GodotLab Collatz Enhanced (presentation over the Direct Collatz scene).
## Run: godot --headless --path . --script res://tools/test_godotlab_collatz_enhanced.gd

const SCENE := "res://games/godotlab_collatz/enhanced/game.tscn"
const DIRECT := "res://games/godotlab_collatz/direct/game.tscn"
const CollatzScript := preload("res://games/godotlab_collatz/direct/collatz.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: godotlab_collatz_enhanced ", msg)
	else:
		print("SMOKE FAIL: godotlab_collatz_enhanced ", msg)
		_fail += 1


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


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
	print("godotlab_collatz_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _no_rules_copy() -> void:
	var src := FileAccess.get_file_as_string("res://games/godotlab_collatz/enhanced/game.gd")
	_check(src.contains("preload(\"res://games/godotlab_collatz/direct/game.tscn\")"),
		"preloads Direct game.tscn")
	_check(not src.contains("func step(") and not src.contains("func set_value")
			and not src.contains("func value(") and not src.contains("func toggle_run"),
		"no stepper copy (step/value/set_value/toggle_run stay Direct)")
	_check(not src.contains("3 * n + 1") and not src.contains("n >> 1 if"), "no Collatz rule expression copy")
	_check(not src.contains("max_value()"), "no overflow-limit copy")
	var files: PackedStringArray = DirAccess.get_files_at("res://games/godotlab_collatz/enhanced/")
	for f in files:
		if f.ends_with(".gd") and f != "game.gd":
			_check(false, "unexpected extra script in enhanced/: " + f)


## Run a bare Direct twin from n to the end; returns [history, steps, peak, value].
func _twin_run(n: int) -> Array:
	var twin: Node = (load(DIRECT) as PackedScene).instantiate()
	root.add_child(twin)
	twin.set_value(n)
	twin._restart_from_bits()
	var guard := 0
	while twin.step() and guard < 500:
		guard += 1
	var out := [twin.history.duplicate(), twin.steps, twin.peak, twin.value()]
	twin.queue_free()
	return out


func _click_bit(inst, i: int) -> void:
	# Stage point → canvas → window coordinates (headless root window is tiny + stretched).
	var p: Vector2 = root.get_final_transform() * (inst.get_global_transform_with_canvas() * inst.bit_pos(i))
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	root.push_input(mv)
	await _physics(2)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		root.push_input(ev)
		await _physics(2)
	await _frames(2)


func _test_scene() -> void:
	_no_rules_copy()
	_check(load(SCENE) is PackedScene, "scene loads")
	_check(load(DIRECT) is PackedScene, "Direct scene still loads")

	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("godotlab_collatz", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "expand",
		"registry: enhanced playable, expand (self-letterboxed 1280×720 stage)")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")
	_check(reg.get_entry("godotlab_collatz", "direct").is_playable(), "registry: direct still playable")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(inst.demo == null and not inst._host.visible, "Direct scene not loaded until Start")
	_check(inst.STAGE == Vector2(1280, 720), "1280×720 stage")

	var backs := 0
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			backs += 1
			_check(b.focus_mode == Control.FOCUS_NONE, "Back to Arcade FOCUS_NONE (%s)" % b.get_path())
		elif b.focus_mode != Control.FOCUS_NONE:
			_check(false, "button %s FOCUS_NONE" % b.text)
	_check(backs >= 2, "Back to Arcade on title card + HUD (%d)" % backs)

	_tap(KEY_SPACE)
	await _frames(3)
	_check(inst.state == inst.PLAY, "Space starts")
	_check(not inst._cards["title"].visible and inst._hud.visible and inst._host.visible,
		"title hidden, HUD + Direct scene shown")
	var d: Node2D = inst.demo
	_check(d.scene_file_path == DIRECT and d.get_script() == CollatzScript, "game is Direct game.tscn/collatz.gd")
	_check(not d.get_node("Hud").visible, "Direct plain HUD hidden (Enhanced draws its own)")
	_check(d.bits.size() == 16 and d.bits.all(func(b): return b.frame == 2), "Direct 16-bit register, bits unset")
	_check(root.physics_object_picking, "Direct enables physics picking for the bits")

	# Framing: every bit inside the register field and the field on the stage.
	var field := Rect2(inst.FIELD_POS, inst.FIELD)
	var inside := true
	for i in 16:
		if not field.has_point(inst.bit_pos(i)):
			inside = false
	_check(inside, "all 16 bits inside the register field")
	_check(inst.bit_pos(0).x > inst.bit_pos(15).x and is_equal_approx(inst.cell(), 64.0),
		"bit 0 rightmost, 64 px cells (cell %.1f)" % inst.cell())
	_check(field.end.x <= 1280 and field.end.y <= 720, "field fits the stage")

	# Real clicks through Direct's Area2D picking (bit.gd: unset → 1, then 1 ↔ 0).
	await _click_bit(inst, 0)
	_check(d.value() == 1 and d.bits[0].frame == 1, "click through Enhanced stage sets bit 0 (n = 1)")
	_check(inst.flips >= 1 and inst._bit_flash[0] > 0.0, "flip juice on the clicked bit")
	await _click_bit(inst, 0)
	_check(d.value() == 0 and d.bits[0].frame == 0, "second click flips bit 0 → 0 (Direct bit.gd rule)")
	await _click_bit(inst, 3)
	await _click_bit(inst, 1)
	_check(d.value() == 10 and d.steps == 0 and d.history == [10], "clicking bits 3 + 1 enters n = 10")

	# Hover inspector.
	inst._mouse_override = inst.bit_pos(4)
	await _frames(2)
	_check(inst.hover_bit == 4, "hover picks bit 4 (got %d)" % inst.hover_bit)
	inst._mouse_override = Vector2(5, 700)
	await _frames(2)
	_check(inst.hover_bit == -1, "no hover off-register")
	inst._mouse_override = null

	# Preset (27) and a key step through Direct's own _unhandled_input.
	_tap(KEY_P)
	await _frames(2)
	_check(d.value() == 27 and d.steps == 0 and d.history == [27], "P loads preset 27 into Direct")
	_check(inst.binary(27).ends_with("11011") and inst.binary(27).length() == 16, "binary readout")
	_tap(KEY_SPACE)
	await _frames(2)
	_check(d.value() == 82 and d.steps == 1, "Space → Direct step 27 → 82")
	_check(inst.last_kind == "3n+1" and inst.last_prev == 27 and inst.last_next == 82 and inst.triples == 1,
		"step panel classifies odd step (3n+1)")
	_check(inst._anim < 1.0, "step animation running")
	_check(inst._n_label.text == "n = 82", "HUD shows n")
	await _frames(1)
	inst.ui_step()
	await _frames(2)
	_check(d.value() == 41 and inst.last_kind == "shift" and inst.shifts == 1, "Step button → shift 82 → 41")

	# Parity: run Enhanced (via Direct's Run, R key) vs a bare Direct twin from 27.
	_tap(KEY_R)
	await _frames(2)
	_check(d.running and inst._run_btn.text == "Stop", "R runs (HUD shows Stop)")
	Engine.time_scale = 8.0  # Direct's RUN_DELAY is game time; speed the run up
	var guard := 0
	while d.running and guard < 2000:
		await _frames(4)
		guard += 1
	await _frames(3)
	Engine.time_scale = 1.0
	var ref := _twin_run(27)
	_check(d.value() == 1 and d.steps == 111 and d.peak == 9232,
		"Enhanced run 27 → 1 in 111 steps, peak 9232 (got %d/%d/%d)" % [d.value(), d.steps, d.peak])
	_check(d.history == ref[0] and d.steps == ref[1] and d.peak == ref[2] and d.value() == ref[3],
		"parity: history/steps/peak match a bare Direct twin")
	_check(inst.shifts + inst.triples == d.steps, "every Direct step observed by the juice (%d+%d)" % [inst.shifts, inst.triples])
	var ups := 0
	for i in ref[0].size() - 1:
		if ref[0][i + 1] > ref[0][i]:
			ups += 1
	_check(inst.triples == ups and inst.shifts == ref[1] - ups,
		"juice odd/even split matches the Direct twin's rises/falls (%d/%d)" % [ups, ref[1] - ups])
	_check(inst.celebrations == 1 and inst._banner.begins_with("REACHED 1"), "reached-1 celebration")

	# Overflow: preset 703 runs into Direct's 16-bit refusal.
	inst.preset_i = 3  # next is 703
	inst.next_preset()
	await _frames(2)
	_check(d.value() == 703, "preset cycles to 703")
	var ref2 := _twin_run(703)
	guard = 0
	while guard < 400:
		var before: int = d.value()
		inst.ui_step()
		if d.value() == before:
			break
		guard += 1
	await _frames(2)
	_check(d.history == ref2[0] and d.value() == ref2[3], "parity: 703 stops where the Direct twin stops (%d)" % d.value())
	_check(d.info.text.contains("overflow") and inst.overflows >= 1 and inst._shake > 0.0,
		"overflow juice (shake + banner) from Direct's refusal")

	_tap(KEY_C)
	await _frames(2)
	_check(d.value() == 0 and d.bits.all(func(b): return b.frame == 2), "C clears via Direct")
	_check(inst.last_kind == "" and inst.shifts == 0, "clear resets the step panel")

	root.push_input(_key(KEY_ESCAPE))
	await _frames(3)
	_check(paused, "Esc opens PauseOverlay and pauses")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	_check(reg.in_arcade() and not paused, "Esc again → Back to Arcade")
