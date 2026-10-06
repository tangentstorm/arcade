extends SceneTree
## Headless checks for Giraffe Enhanced (presentation over Direct logic).
## Run: godot --headless --path . --script res://tools/test_giraffe_enhanced.gd

const Logic := preload("res://games/giraffe/direct/giraffe_logic.gd")
const SCENE := "res://games/giraffe/enhanced/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: giraffe_enhanced ", msg)
	else:
		print("SMOKE FAIL: giraffe_enhanced ", msg)
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
	_test_parity_vs_direct()
	_test_juice_and_stats()
	await _test_scene()
	print("giraffe_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _same(a, b) -> bool:
	return is_equal_approx(a.hx, b.hx) and is_equal_approx(a.hy, b.hy) \
		and is_equal_approx(a.dx, b.dx) and is_equal_approx(a.dy, b.dy) \
		and a.frame == b.frame and a.flip_x == b.flip_x and a.on_ground == b.on_ground \
		and a.tm == b.tm and a.wf == b.wf


## A scripted session through Enhanced tick() must leave the same Direct-owned
## state as the same inputs on a bare Direct twin (including falls / resets).
func _test_parity_vs_direct() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	_check(inst.world.get_script() == Logic, "uses the Direct giraffe_logic.gd (no rules copy)")
	var d = Logic.new()
	var script := [
		[20, {}], [25, {"right": true}], [8, {"right": true, "jump": true}],
		[30, {"right": true}], [12, {"left": true, "jump": true}], [40, {"left": true}],
		[60, {"right": true, "jump": true}], [90, {"right": true}], [40, {}],
		[50, {"left": true, "jump": true}], [80, {"left": true}],
	]
	var same := true
	var n := 0
	for seg in script:
		for i in seg[0]:
			d.step(seg[1])
			inst.tick(seg[1])
			same = same and _same(d, inst.world)
			n += 1
	_check(same, "hero state matches Direct twin every frame (%d scripted frames)" % n)
	_check(inst.falls > 0, "scripted run includes at least one fall/reset (falls=%d)" % inst.falls)
	_check(inst.jumps > 0, "scripted run counted jumps (jumps=%d)" % inst.jumps)
	inst.free()


func _test_juice_and_stats() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	_check(inst.ledges.size() == 7, "7 contiguous tile-16 ledges found from Direct map (%d)" % inst.ledges.size())
	_check(inst.ledge_at(Vector2i(0, 5)) >= 0 and inst.ledge_at(Vector2i(6, 5)) == inst.ledge_at(Vector2i(7, 5)),
		"ledge lookup groups contiguous tiles")
	_check(inst.state == inst.TITLE, "boots on title; sim idle")
	inst.start()
	_check(inst.state == inst.PLAY and not inst._cards["title"].visible, "start() leaves title")

	# Spawn falls onto ledge (0,5): landing juice + first ledge visit.
	for i in 40:
		inst.tick({})
	_check(inst.world.on_ground, "hero landed on spawn ledge")
	_check(inst.visited.has(inst.ledge_at(Vector2i(0, 5))), "spawn ledge marked visited")
	_check(inst.air_frames == 0 and inst.best_air > 0, "air time tracked (best_air=%d)" % inst.best_air)
	var p0: int = inst._particles.size()
	inst.tick({"jump": true})
	_check(inst.jumps == 1 and inst._squash.y > 1.0, "jump: counter + stretch")
	_check(inst._particles.size() > p0, "jump: dust particles")
	for i in 20:
		inst.tick({})
	_check(inst._squash.x > 1.0 or inst.world.on_ground, "lands again after hop")

	# Fall off the bottom -> Direct reset -> Enhanced counts a fall.
	inst.world.hy = 130.0
	inst.world.dy = 3.0
	inst._snap_prev()
	inst.tick({})
	_check(inst.falls == 1 and is_equal_approx(inst.world.hy, 16.0), "fall below 128 -> Direct reset + fall counter")
	_check(inst._floaters.size() > 0 and inst._flash > 0.0, "fall: WHOOPS floater + flash")

	# Visiting every ledge triggers the ALL LEDGES toast once.
	for i in inst.ledges.size():
		inst._visit(i)
	_check(inst.visited.size() == inst.ledges.size() and inst.all_time > 0 and inst._toast_t > 0.0,
		"all ledges visited -> toast + best run time")
	inst._refresh_hud()
	_check(inst._ledge_label.text == "7 / 7", "HUD shows ledges 7 / 7")
	inst.free()


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("giraffe", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("giraffe", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.state == inst.TITLE and inst._cards["title"].visible, "boots on the title card")
	var hy0: float = inst.world.hy
	await _frames(10)
	_check(is_equal_approx(inst.world.hy, hy0), "sim idle on title")

	var back: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			back = b
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")

	root.push_input(_key(KEY_SPACE))
	root.push_input(_key(KEY_SPACE, false))
	await _frames(20)
	_check(inst.state == inst.PLAY and not inst._cards["title"].visible, "Space leaves title for play")
	_check(inst.play_frames > 0, "sim steps in play (%d frames)" % inst.play_frames)

	# Esc -> PauseOverlay (tree pause freezes the 30 Hz step), Esc again -> arcade
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	var f0: int = inst.play_frames
	await _frames(8)
	_check(paused and inst.play_frames == f0, "Esc opens PauseOverlay and freezes the sim")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
