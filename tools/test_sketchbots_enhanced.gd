extends SceneTree
## Headless checks for SketchBots Enhanced (presentation over Direct sketchbots_logic.gd).
## Run: godot --headless --path . --script res://tools/test_sketchbots_enhanced.gd

const Logic := preload("res://games/sketchbots/direct/sketchbots_logic.gd")
const SCENE := "res://games/sketchbots/enhanced/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: sketchbots_enhanced ", msg)
	else:
		print("SMOKE FAIL: sketchbots_enhanced ", msg)
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
	print("sketchbots_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _test_no_rules_copy() -> void:
	var src := FileAccess.get_file_as_string("res://games/sketchbots/enhanced/game.gd")
	_check(src.find("func _advance(") < 0 and src.find("func step(") < 0 \
			and src.find("const NORTH :=") < 0 and src.find("const SPEED :=") < 0,
			"enhanced/ defines no rules functions (_advance/step/NORTH/SPEED)")
	_check(src.find('preload("res://games/sketchbots/direct/sketchbots_logic.gd")') >= 0,
			"enhanced preloads Direct sketchbots_logic.gd")
	_check(src.find('preload("res://games/sketchbots/direct/assets/') >= 0,
			"enhanced preloads Direct sprite assets")


func _same(a, b) -> bool:
	return a.orange_x == b.orange_x and a.orange_y == b.orange_y \
		and a.orange_face == b.orange_face and a.heading == b.heading \
		and a.blue_x == b.blue_x and a.blue_y == b.blue_y \
		and a.blue_face == b.blue_face and a.blue_heading == b.blue_heading


## A scripted session through Enhanced tick() must leave the same Direct-owned
## state as the same steps on a bare Logic twin.
func _test_parity_vs_direct() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	_check(inst.world.get_script() == Logic, "uses the Direct sketchbots_logic.gd (no rules copy)")
	inst.world = Logic.new()
	var d = Logic.new()
	inst.playing = true
	inst._show_card("")
	inst._snap_prev()
	# Script: press keys once, then step many frames, release, move the other bot, etc.
	var script := [
		{"actions": [["d", true]], "steps": 1},
		{"actions": [], "steps": 4},
		{"actions": [["w", true]], "steps": 1},
		{"actions": [], "steps": 3},
		{"actions": [["w", false], ["d", false]], "steps": 1},
		{"actions": [["up", true]], "steps": 1},
		{"actions": [], "steps": 5},
		{"actions": [["right", true]], "steps": 1},
		{"actions": [], "steps": 4},
		{"actions": [["up", false], ["right", false]], "steps": 1},
		{"actions": [["a", true], ["left", true]], "steps": 1},
		{"actions": [], "steps": 6},
		{"actions": [["a", false], ["left", false]], "steps": 1},
		{"actions": [["s", true], ["down", true]], "steps": 1},
		{"actions": [], "steps": 8},
		{"actions": [["s", false], ["down", false]], "steps": 1},
		# Drive orange off the top (no clamp) and blue against the bottom clamp.
		{"actions": [["w", true]], "steps": 1},
		{"actions": [], "steps": 20},
		{"actions": [["w", false]], "steps": 1},
		{"actions": [["down", true]], "steps": 1},
		{"actions": [], "steps": 10},
		{"actions": [["down", false]], "steps": 1},
		# XOR release quirk without a matching press.
		{"actions": [["a", false]], "steps": 1},
		{"actions": [], "steps": 2},
		{"actions": [["a", false]], "steps": 1},  # flip west off again via XOR
	]
	var same := true
	var n := 0
	for seg in script:
		var acts: Array = seg.actions
		# Apply key actions on the bare twin; Enhanced tick() applies them on its first step.
		for a in acts:
			d.handle_key(String(a[0]), bool(a[1]))
		for i in seg.steps:
			if i == 0:
				inst.tick(acts)
			else:
				inst.tick([])
			d.step()
			same = same and _same(d, inst.world)
			n += 1
	_check(same, "orange/blue pos/face/heading match Direct over %d scripted ticks" % n)
	_check(inst.world.orange_y < 0, "script drove orange off the top (y=%d)" % inst.world.orange_y)
	_check(inst.world.blue_y == Logic.H - inst.world.blue_h, "script bottom-clamped blue (y=%d)" % inst.world.blue_y)
	inst.free()


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("sketchbots", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("sketchbots", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.world.get_script() == Logic, "launched world is Direct sketchbots_logic.gd")
	_check(not inst.playing and inst._cards["title"].visible, "boots on the title card")
	_check(inst.world.orange_x == 125 and inst.world.blue_y == 250, "title holds start poses")

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
		"field is 300×300 @2× (600×600)")
	_check(Rect2(Vector2.ZERO, inst.STAGE).encloses(Rect2(field.position, field.size)),
		"field fits inside the 1280×720 stage")

	# Keys do nothing on the title card (sim idle).
	var ox0: int = inst.world.orange_x
	root.push_input(_key(KEY_D))
	root.push_input(_key(KEY_D, false))
	await _frames(4)
	_check(inst.world.orange_x == ox0 and not inst.playing, "title ignores movement keys")

	# Space starts play.
	root.push_input(_key(KEY_SPACE))
	root.push_input(_key(KEY_SPACE, false))
	await _frames(3)
	_check(inst.playing and not inst._cards["title"].visible, "Space leaves the title for play")

	# Walk juice via tick: dust + squash when orange moves.
	var p0: int = inst._particles.size()
	inst.tick([["d", true]])
	for i in 3:
		inst.tick([])
	_check(inst.world.orange_x > ox0, "orange moved east via tick")
	_check(inst._particles.size() > p0 or inst._squash_o != Vector2.ONE, "move: dust / squash juice")
	inst.tick([["d", false]])

	# Meet juice: place bots so AABBs overlap.
	inst.world.orange_x = 120
	inst.world.orange_y = 120
	inst.world.blue_x = 130
	inst.world.blue_y = 130
	inst._snap_prev()
	inst._prev_overlap = false
	var m0: int = inst._meets
	var f0: int = inst._floaters.size()
	inst.tick([])
	_check(inst._meets > m0, "overlap increments meet counter")
	_check(inst._floaters.size() > f0 or inst._particles.size() > 0, "meet: HI! floater / burst juice")
	_check(inst._shake > 0.0 or inst._flash > 0.0, "meet: shake / flash juice")

	# Off-canvas juice: drive orange above the top.
	inst.world.orange_x = 125
	inst.world.orange_y = 5
	inst.world.heading = 0
	inst._snap_prev()
	inst._prev_orange_off = false
	var off0: int = inst._off_canvas_events
	inst.tick([["w", true]])
	inst.tick([])
	_check(inst.world.orange_y < 0, "orange left the top of the canvas")
	_check(inst._off_canvas_events > off0, "off-canvas event counted")
	inst.tick([["w", false]])

	# Esc → PauseOverlay (tree pause), Esc again → arcade
	var steps0: int = inst._steps
	root.push_input(_key(KEY_ESCAPE))
	await _frames(8)
	_check(paused and inst._steps == steps0, "Esc opens PauseOverlay and freezes the run")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
