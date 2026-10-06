extends SceneTree
## Capture in-game preview PNGs for every playable Direct edition.
## Run via tools/capture_previews.sh (Xvfb + non-headless so GL renders).
## Output: res://arcade/previews/<id>_direct.png

const OUT_DIR := "res://arcade/previews"
const WARM_FRAMES := 45
const AFTER_INPUT_FRAMES := 90
const SETTLE_FRAMES := 12

var _ok := 0
var _fail := 0
var _skip := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var registry = root.get_node_or_null("GameRegistry")
	if registry == null:
		print("CAPTURE FAIL: GameRegistry missing")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	for e in registry.entries:
		if e.edition != "direct":
			continue
		if not e.is_playable():
			print("skip planned: ", e.id)
			_skip += 1
			continue
		var existing := "%s/%s_direct.png" % [OUT_DIR, e.id]
		if FileAccess.file_exists(existing) and not OS.get_environment("CAPTURE_FORCE") == "1":
			print("skip existing: ", e.id)
			_skip += 1
			_ok += 1
			continue
		var ok := await _capture_one(e)
		if ok:
			_ok += 1
		else:
			_fail += 1

	print("capture: %d ok, %d fail, %d skipped" % [_ok, _fail, _skip])
	quit(1 if _fail else 0)


func _capture_one(entry) -> bool:
	print("capturing: ", entry.id, " <- ", entry.scene_path)
	var packed := load(entry.scene_path) as PackedScene
	if packed == null:
		print("CAPTURE FAIL: cannot load ", entry.scene_path)
		return false
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	if inst is Control:
		var c := inst as Control
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.set_deferred("size", Vector2(1280, 720))
	await _frames(WARM_FRAMES)
	await _warmup(entry.id, inst)
	await _frames(AFTER_INPUT_FRAMES)
	for i in SETTLE_FRAMES:
		await process_frame
		await RenderingServer.frame_post_draw

	var img: Image = root.get_viewport().get_texture().get_image()
	inst.queue_free()
	await process_frame
	if img == null:
		print("CAPTURE FAIL: null image for ", entry.id)
		return false
	if _mostly_black(img):
		print("CAPTURE WARN: mostly black for ", entry.id, " (saving anyway)")
	var path := "%s/%s_direct.png" % [OUT_DIR, entry.id]
	var err := img.save_png(path)
	if err != OK:
		print("CAPTURE FAIL: save ", path, " err=", err)
		return false
	print("saved: ", ProjectSettings.globalize_path(path), " ", img.get_width(), "x", img.get_height())
	return true


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _press_key(keycode: int, pressed: bool = true) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	ev.echo = false
	Input.parse_input_event(ev)


func _tap_key(keycode: int) -> void:
	_press_key(keycode, true)
	await process_frame
	_press_key(keycode, false)
	await process_frame


func _hold_key(keycode: int, frames: int) -> void:
	_press_key(keycode, true)
	await _frames(frames)
	_press_key(keycode, false)
	await process_frame


func _click_at(pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos
	Input.parse_input_event(press)
	await process_frame
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = pos
	rel.global_position = pos
	Input.parse_input_event(rel)
	await process_frame


func _drag(from: Vector2, to: Vector2, release: bool = true) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	Input.parse_input_event(press)
	await process_frame
	for i in range(1, 11):
		var mv := InputEventMouseMotion.new()
		mv.position = from.lerp(to, i / 10.0)
		mv.global_position = mv.position
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mv)
		await process_frame
	if release:
		var rel := InputEventMouseButton.new()
		rel.button_index = MOUSE_BUTTON_LEFT
		rel.pressed = false
		rel.position = to
		rel.global_position = to
		Input.parse_input_event(rel)
		await process_frame


func _move_mouse(pos: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	Input.parse_input_event(mv)
	await process_frame


func _warmup(id: String, inst: Node) -> void:
	match id:
		"cupid":
			await _tap_key(KEY_SPACE)
			await _frames(20)
			await _move_mouse(Vector2(900, 280))
			await _frames(40)
			await _click_at(Vector2(900, 280))
		"gm_defense":
			# speed=5 from Create carries the ship off-screen in ~2s; turn it around.
			await _tap_key(KEY_LEFT)
			await _frames(30)
			await _tap_key(KEY_RIGHT)
		"ok_defender":
			await _tap_key(KEY_SPACE)
			await _hold_key(KEY_RIGHT, 30)
			await _hold_key(KEY_SPACE, 10)
		"invader_sketch":
			await _tap_key(KEY_SPACE)
			await _hold_key(KEY_LEFT, 20)
			await _tap_key(KEY_SPACE)
		"flappy_clone":
			await _tap_key(KEY_SPACE)
			await _frames(15)
			await _tap_key(KEY_SPACE)
			await _frames(20)
			await _tap_key(KEY_SPACE)
		"shep":
			await _tap_key(KEY_SPACE)
			await _frames(10)
			await _tap_key(KEY_ENTER)
			await _frames(10)
			_try_click_button(inst, ["Play", "Start", "1", "0000"])
			await _frames(20)
		"brickslayer":
			await _tap_key(KEY_SPACE)
			await _frames(10)
			await _tap_key(KEY_ENTER)
			await _hold_key(KEY_RIGHT, 25)
			await _tap_key(KEY_SPACE)
		"killem_all":
			# Thrust a little, aim up-right and spray bullets.
			Input.warp_mouse(Vector2(1000, 150))  # the Xvfb pointer wins over synthetic motion
			await _move_mouse(Vector2(1000, 150))
			await _hold_key(KEY_D, 8)
			var fire := InputEventMouseButton.new()
			fire.button_index = MOUSE_BUTTON_LEFT
			fire.position = Vector2(1000, 150)
			fire.global_position = fire.position
			fire.pressed = true
			Input.parse_input_event(fire)
			# Keep firing through the shot; release a few seconds later.
			create_timer(3.0).timeout.connect(func() -> void:
				var up := fire.duplicate() as InputEventMouseButton
				up.pressed = false
				Input.parse_input_event(up))
		"tetraminex":
			await _hold_key(KEY_RIGHT, 15)
			await _hold_key(KEY_DOWN, 10)
		"tentraminos":
			await _hold_key(KEY_RIGHT, 20)
			await _tap_key(KEY_UP)
			await _hold_key(KEY_DOWN, 10)
		"sketchbots":
			await _hold_key(KEY_D, 25)
			await _hold_key(KEY_W, 15)
		"toroidal_zombie_herder":
			await _hold_key(KEY_RIGHT, 30)
			await _hold_key(KEY_UP, 20)
		"godotlab_game00", "godotlab_game01", "godotlab_tilemap":
			await _hold_key(KEY_RIGHT, 25)
			await _hold_key(KEY_UP, 15)
		"godotlab_collatz":
			await _tap_key(KEY_SPACE)
			await _frames(30)
			await _tap_key(KEY_SPACE)
			await _frames(30)
		"overlap_demo", "overlap_demo_live":
			# 300×300 sketch at 2.4× from x=280: drag the centre square onto its right neighbour.
			await _drag(Vector2(280 + 2.4 * 137, 2.4 * 137), Vector2(280 + 2.4 * 197, 2.4 * 145))
		"bullet_demo":
			await _click_at(Vector2(280 + 2.4 * 55, 2.4 * 200))
			await _frames(20)
			await _click_at(Vector2(280 + 2.4 * 130, 2.4 * 200))
		"gamesketchlib_demo", "bullet_demo_live":
			await _click_at(Vector2(640, 360))
			await _frames(10)
			await _click_at(Vector2(280 + 2.4 * 55, 2.4 * 200))
			await _frames(20)
			await _click_at(Vector2(280 + 2.4 * 205, 2.4 * 200))
		"keyboard_test_workaround", "keyboard_test_buggy", "keyboard_test_hashmap":
			# Leave D + Up held so the pads show lit keys in the shot.
			_press_key(KEY_D, true)
			_press_key(KEY_UP, true)
			await _frames(5)
		"fnarb_overlap":
			# 1920×1080 stage at 2/3: drag box (125,50) onto box (200,50).
			await _move_mouse(Vector2(141, 66) * (2.0 / 3.0))
			await _drag(Vector2(141, 66) * (2.0 / 3.0), Vector2(200, 80) * (2.0 / 3.0), false)
		"mineswpr":
			await _click_at(Vector2(640, 300))
			await _frames(5)
			await _click_at(Vector2(700, 340))
		"ld48":
			await _hold_key(KEY_RIGHT, 20)
			await _hold_key(KEY_UP, 10)
		"ofcp":
			await _frames(60)
		"_template":
			pass
		_:
			await _tap_key(KEY_SPACE)
			await _hold_key(KEY_RIGHT, 15)


func _try_click_button(root_node: Node, labels: Array) -> void:
	var buttons: Array = []
	_collect_buttons(root_node, buttons)
	for b in buttons:
		var btn := b as BaseButton
		if btn == null or not btn.visible or btn.disabled:
			continue
		var label_text := ""
		if btn is Button:
			label_text = str((btn as Button).text).strip_edges()
		for label in labels:
			if label_text == label or (label_text != "" and label_text.begins_with(str(label))):
				btn.pressed.emit()
				await process_frame
				return
	for b in buttons:
		var btn2 := b as BaseButton
		if btn2 != null and btn2.visible and not btn2.disabled:
			btn2.pressed.emit()
			await process_frame
			return


func _collect_buttons(n: Node, out: Array) -> void:
	if n is BaseButton:
		out.append(n)
	for c in n.get_children():
		_collect_buttons(c, out)


func _mostly_black(img: Image) -> bool:
	var black := 0
	var samples := 0
	var step := maxi(1, mini(img.get_width(), img.get_height()) / 24)
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			samples += 1
			var c := img.get_pixel(x, y)
			if c.r + c.g + c.b < 0.08:
				black += 1
	return samples > 0 and float(black) / float(samples) > 0.92
