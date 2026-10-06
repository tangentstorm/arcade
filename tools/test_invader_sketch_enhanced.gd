extends SceneTree
## Headless checks for Invader Sketch Enhanced (presentation over Direct invader_logic.gd).
## Run: godot --headless --path . --script res://tools/test_invader_sketch_enhanced.gd

const Logic := preload("res://games/invader_sketch/direct/invader_logic.gd")
const SCENE := "res://games/invader_sketch/enhanced/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: invader_sketch_enhanced ", msg)
	else:
		print("SMOKE FAIL: invader_sketch_enhanced ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_test_no_rules_copy()
	_test_parity_vs_direct()
	await _test_scene()
	print("invader_sketch_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _test_no_rules_copy() -> void:
	# Enhanced folder should not redefine Simulation helpers from Direct.
	var src := FileAccess.get_file_as_string("res://games/invader_sketch/enhanced/game.gd")
	_check(src.find("class GsTimer") < 0 and src.find("func shoot(") < 0 \
			and src.find("func _update_invaders") < 0,
			"enhanced/ defines no rules functions (GsTimer/shoot/_update_invaders)")
	_check(src.find('preload("res://games/invader_sketch/direct/invader_logic.gd")') >= 0,
			"enhanced preloads Direct invader_logic.gd")


## A scripted session through Enhanced tick() must leave the same Direct-owned
## state as the same steps on a bare Logic twin (same seed).
func _test_parity_vs_direct() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	_check(inst.world.get_script() == Logic, "uses the Direct invader_logic.gd (no rules copy)")
	inst.world = Logic.new(Logic.PLAY, 42)
	var d = Logic.new(Logic.PLAY, 42)
	inst._show_card("")
	inst._snap_prev()
	var inputs := [
		{"just": [], "left": true, "right": false},
		{"just": ["space"], "left": false, "right": false},
		{"just": [], "left": false, "right": true},
		{"just": [], "left": false, "right": false},
		{"just": ["space"], "left": true, "right": false},
		{"just": [], "left": false, "right": true},
	]
	var same := true
	for i in 240:
		var inp: Dictionary = inputs[i % inputs.size()]
		d.step(inp)
		inst.tick(inp)
		var g = inst.world
		same = same and g.state == d.state \
			and is_equal_approx(g.hero.x, d.hero.x) \
			and g.invaders.size() == d.invaders.size() \
			and g.ship_invaders.size() == d.ship_invaders.size() \
			and g.shields.size() == d.shields.size() \
			and g.bullets_left == d.bullets_left \
			and g.enemy_bullets.size() == d.enemy_bullets.size() \
			and g.frames_played == d.frames_played \
			and g.drift_x == d.drift_x \
			and g.fleet_speed_x == d.fleet_speed_x
	_check(same, "hero/fleet/shields/ammo/enemy bullets/state match Direct over 240 ticks")
	_check(inst.world.frames_played == 240, "scripted session advanced 240 play frames")
	inst.free()


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("invader_sketch", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("invader_sketch", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.world.get_script() == Logic, "launched world is Direct invader_logic.gd")
	_check(inst.world.state == Logic.MENU and inst._cards["title"].visible, "boots on the title card")

	var back: Button = null
	var start: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			back = b
		elif b.text == "Start":
			start = b
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")
	_check(start != null, "title has a Start button")

	var field: Control = inst._field
	_check(field != null and field.clip_contents, "field exists and clips")
	_check(is_equal_approx(field.size.x, Logic.W * inst.PX) \
		and is_equal_approx(field.size.y, Logic.H * inst.PX),
		"field is 640×480 @1.5× (960×720)")
	_check(Rect2(Vector2.ZERO, inst.STAGE).encloses(Rect2(field.position, field.size)),
		"field fits inside the 1280×720 stage")

	# Space starts play (Direct Menu → Play).
	root.push_input(_key(KEY_SPACE))
	root.push_input(_key(KEY_SPACE, false))
	await _frames(4)
	_check(inst.world.state == Logic.PLAY and not inst._cards["title"].visible, "Space leaves the title for play")

	# Shoot juice via tick.
	inst.world = Logic.new(Logic.PLAY, 3)
	inst.world.hero.x = 200
	inst._show_card("")
	inst._snap_prev()
	var p0: int = inst._particles.size()
	inst.tick({"just": ["space"], "left": false, "right": false})
	_check(inst.world.bullets_left == 2, "shoot uses one Direct bullet")
	_check(inst._particles.size() > p0 or inst._muzzle > 0.0 or inst._shake > 0.0,
		"shoot: muzzle juice / shake")

	# Kill juice: drive a bullet into an invader (same seed path as Direct test).
	var before: int = inst.world.invaders.size()
	var float0: int = inst._floaters.size()
	var n := 0
	while inst.world.invaders.size() == before and n < 400:
		inst.tick({})
		n += 1
	_check(inst.world.invaders.size() == before - 1, "bullet kills an invader through Direct (frame %d)" % n)
	_check(inst._kills >= 1 and (inst._floaters.size() > float0 or inst._particles.size() > 0),
		"kill: +1 floater / burst juice")

	# Force win card path.
	inst.world.invaders.clear()
	inst.world.ship_invaders.clear()
	inst._prev_state = Logic.PLAY
	inst._prev_invaders = 1
	inst.tick({})  # checkForWin → WIN
	await _frames(2)
	_check(inst.world.state == Logic.WIN, "clearing the fleet wins")
	_check(inst._cards["win"].visible, "win card shows")

	# Game-over card path (presentation observes Direct state).
	inst.world = Logic.new(Logic.PLAY, 9)
	inst._show_card("")
	inst._snap_prev()
	inst._prev_state = Logic.PLAY
	inst.world.state = Logic.GAMEOVER
	inst._observe()
	await _frames(2)
	_check(inst._cards["over"].visible, "game-over card shows")
	_check(inst._shake > 0.0 or inst._flash > 0.0, "game-over: shake / flash juice")

	# Esc → PauseOverlay (tree pause), Esc again → arcade
	# Relaunch clean play for Esc freeze check.
	reg.launch(entry)
	await _frames(4)
	inst = current_scene
	inst.tick({"just": ["space"]})
	await _frames(2)
	var f0: int = inst.world.frames_played
	root.push_input(_key(KEY_ESCAPE))
	await _frames(8)
	_check(paused and inst.world.frames_played == f0, "Esc opens PauseOverlay and freezes the sim")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
