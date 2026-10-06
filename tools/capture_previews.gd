extends SceneTree
## Capture in-game preview PNGs for playable editions.
## Run via tools/capture_previews.sh (Xvfb + non-headless so GL renders).
## Output: res://arcade/previews/<id>_<edition>.png (640x360)
## Env:
##   CAPTURE_EDITION=direct (default) | enhanced | both
##   CAPTURE_ONLY=<id>   limit to one title
##   CAPTURE_FORCE=1     re-shoot existing PNGs

const OUT_DIR := "res://arcade/previews"
const PREVIEW_W := 640
const PREVIEW_H := 360
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

	var only := OS.get_environment("CAPTURE_ONLY").strip_edges()
	var want := OS.get_environment("CAPTURE_EDITION").strip_edges().to_lower()
	if want == "":
		want = "direct"
	if not want in ["direct", "enhanced", "both"]:
		print("CAPTURE FAIL: CAPTURE_EDITION must be direct, enhanced or both (got '%s')" % want)
		quit(2)
		return
	print("capture edition: ", want)
	for e in registry.entries:
		if want != "both" and e.edition != want:
			continue
		if only != "" and e.id != only:
			continue
		if not e.is_playable():
			print("skip not playable: ", e.id, " (", e.edition, ")")
			_skip += 1
			continue
		var existing := "%s/%s_%s.png" % [OUT_DIR, e.id, e.edition]
		if FileAccess.file_exists(existing) and not OS.get_environment("CAPTURE_FORCE") == "1":
			print("skip existing: ", e.id, " (", e.edition, ")")
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
	print("capturing: ", entry.id, " (", entry.edition, ") <- ", entry.scene_path)
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
	if entry.edition == "enhanced" and _has_enhanced_warmup(entry.id):
		await _warmup_enhanced(entry.id, inst)
	else:
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
	## Cards are ~260-400 px wide; 640x360 keeps index.pck small (see docs/SLIM_WEB_ENGINE.md).
	img.resize(PREVIEW_W, PREVIEW_H, Image.INTERPOLATE_LANCZOS)
	var path := "%s/%s_%s.png" % [OUT_DIR, entry.id, entry.edition]
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
			await _try_click_button(inst, ["Play", "Start", "1", "0000"])
			await _frames(20)
		"brickslayer":
			await _tap_key(KEY_SPACE)
			await _frames(10)
			await _tap_key(KEY_ENTER)
			await _hold_key(KEY_RIGHT, 25)
			await _tap_key(KEY_SPACE)
		"spiders_v_aliens":
			for i in 3:
				await _tap_key(KEY_SPACE)
				await _frames(10)
			await _hold_key(KEY_LEFT, 40)
			await _hold_key(KEY_UP, 25)
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
		"canyon_run":
			await _hold_key(KEY_SPACE, 10)
			await _hold_key(KEY_LEFT, 12)
			await _hold_key(KEY_SPACE, 20)
		"silly_game":
			await _hold_key(KEY_D, 30)
			await _hold_key(KEY_W, 15)
			await _click_at(Vector2(900, 300))
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
		"mineswpr", "mineswpr_b4":
			await _click_at(Vector2(640, 300))
			await _frames(5)
			await _click_at(Vector2(700, 340))
		"ld48":
			await _hold_key(KEY_RIGHT, 20)
			await _hold_key(KEY_UP, 10)
		"ofcp":
			await _frames(60)
		"terratri":
			# Golden seed 2 one step before Red's winning fort (4 forts each side of the race).
			for ch in "wk|EES|ex|WK|enx|ESF|wk|NK|nenf|NK|ef|WWX|wk|WX|ek|WESX|wwfs|FWF|fw|SF|".replace("|", ""):
				inst.play_step(ch)
			await _move_mouse(Vector2(640, 330))
		"_template":
			pass
		_:
			await _tap_key(KEY_SPACE)
			await _hold_key(KEY_RIGHT, 15)


## Enhanced scenes whose controls/flow differ from Direct. Anything not listed
## here reuses the Direct warmup in _warmup(). Most Enhanced shells open on a
## title card that Space/Enter dismisses; Direct warmups that never tap Space
## therefore freeze on the card.
const ENHANCED_WARMUPS: Array[String] = [
	"mineswpr", "tetraminex",
	"shep", "ld48", "ok_defender", "silly_game", "sketchbots", "terratri",
	"killem_all", "toroidal_zombie_herder", "godotlab_game00", "godotlab_game01",
	"godotlab_tilemap", "godotlab_collatz", "ofcp", "gm_defense", "invader_sketch",
]


func _has_enhanced_warmup(id: String) -> bool:
	return id in ENHANCED_WARMUPS


func _dismiss_enhanced_title(inst: Node) -> void:
	# Space/Enter start most Enhanced shells; also poke a Start/Play button.
	await _tap_key(KEY_SPACE)
	await _frames(10)
	await _try_click_button(inst, ["Start", "Play", "Press Space to begin"])
	await _frames(20)


func _warmup_enhanced(id: String, inst: Node) -> void:
	match id:
		"tetraminex":
			# Room 0 opens on a talk card: dismiss it, jump to room 1 (blocks + cages),
			# dismiss Teddy's card, then take a couple of steps.
			await _tap_key(KEY_SPACE)
			await _frames(15)
			await _tap_key(KEY_1)
			await _frames(20)
			for i in 3:
				await _tap_key(KEY_SPACE)
				await _frames(10)
			await _hold_key(KEY_RIGHT, 15)
		"mineswpr":
			# No first-click safety and a random board: open a few zero cells (floods)
			# nearest the centre via click_cell, then flag mines bordering the opening.
			var g = inst.game
			var zeros: Array = []
			for c in g.grid.size():
				if not g.has(c, 0) and g.has(c, 1) and (g.grid[c] >> 8) == 0:
					zeros.append(c)
			var centre := Vector2(7.5, 7.5)
			zeros.sort_custom(func(a, b): return Vector2(a % 16, a / 16).distance_to(centre) < Vector2(b % 16, b / 16).distance_to(centre))
			var opened := 0
			for c in zeros:
				if opened >= 3:
					break
				if g.has(c, 1):
					inst.click_cell(c % 16, c / 16, MOUSE_BUTTON_LEFT)
					opened += 1
					await _frames(10)
			var flagged := 0
			for c in g.grid.size():
				if flagged >= 3:
					break
				if not g.has(c, 0) or g.has(c, 2):
					continue
				var x: int = c % 16
				var y: int = c / 16
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and nx < 16 and ny >= 0 and ny < 16 and not g.has(ny * 16 + nx, 1):
						inst.click_cell(x, y, MOUSE_BUTTON_RIGHT)
						flagged += 1
						await _frames(5)
						break
		"shep":
			# Title -> Play -> Level 1 -> brief settle on the airlock puzzle.
			await _try_click_button(inst, ["Play"])
			await _frames(20)
			await _try_click_button(inst, ["Level 1"])
			await _frames(40)
			await _hold_key(KEY_RIGHT, 15)
			await _hold_key(KEY_UP, 10)
		"ok_defender":
			# Space starts play AND is fire — tap once to leave title, then fly only.
			await _tap_key(KEY_SPACE)
			await _frames(20)
			await _hold_key(KEY_RIGHT, 40)
			await _hold_key(KEY_UP, 20)
		"terratri":
			await _dismiss_enhanced_title(inst)
			# Golden seed 2 one step before Red's winning fort (4 forts each side).
			for ch in "wk|EES|ex|WK|enx|ESF|wk|NK|nenf|NK|ef|WWX|wk|WX|ek|WESX|wwfs|FWF|fw|SF|".replace("|", ""):
				inst.play_step(ch)
			await _move_mouse(Vector2(640, 330))
			await _frames(15)
		"ld48", "silly_game":
			await _dismiss_enhanced_title(inst)
			await _hold_key(KEY_RIGHT, 25)
			await _hold_key(KEY_UP, 15)
			await _hold_key(KEY_D, 20)
		"sketchbots":
			await _dismiss_enhanced_title(inst)
			await _hold_key(KEY_D, 30)
			await _hold_key(KEY_W, 20)
			await _hold_key(KEY_RIGHT, 25)
		"killem_all":
			await _dismiss_enhanced_title(inst)
			Input.warp_mouse(Vector2(1000, 150))
			await _move_mouse(Vector2(1000, 150))
			await _hold_key(KEY_D, 12)
			var fire := InputEventMouseButton.new()
			fire.button_index = MOUSE_BUTTON_LEFT
			fire.position = Vector2(1000, 150)
			fire.global_position = fire.position
			fire.pressed = true
			Input.parse_input_event(fire)
			create_timer(2.0).timeout.connect(func() -> void:
				var up := fire.duplicate() as InputEventMouseButton
				up.pressed = false
				Input.parse_input_event(up))
			await _frames(30)
		"toroidal_zombie_herder":
			await _dismiss_enhanced_title(inst)
			await _hold_key(KEY_RIGHT, 35)
			await _hold_key(KEY_UP, 25)
		"godotlab_game00", "godotlab_game01", "godotlab_tilemap":
			await _dismiss_enhanced_title(inst)
			await _hold_key(KEY_RIGHT, 30)
			await _hold_key(KEY_UP, 20)
			await _hold_key(KEY_D, 15)
		"godotlab_collatz":
			await _dismiss_enhanced_title(inst)
			await _tap_key(KEY_SPACE)
			await _frames(40)
			await _tap_key(KEY_SPACE)
			await _frames(40)
		"ofcp":
			await _dismiss_enhanced_title(inst)
			await _frames(90)
		"gm_defense":
			await _dismiss_enhanced_title(inst)
			await _tap_key(KEY_LEFT)
			await _frames(30)
			await _tap_key(KEY_RIGHT)
			await _frames(20)
		"invader_sketch":
			await _dismiss_enhanced_title(inst)
			await _hold_key(KEY_LEFT, 25)
			await _tap_key(KEY_SPACE)
			await _frames(20)
		_:
			await _warmup(id, inst)


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
