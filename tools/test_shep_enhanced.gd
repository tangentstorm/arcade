extends SceneTree
## Headless checks for Shep Enhanced (presentation over Direct physics/levels).
## Run: godot --headless --path . --script res://tools/test_shep_enhanced.gd

const Levels := preload("res://games/shep/direct/shep_levels.gd")
const World := preload("res://games/shep/direct/shep_world.gd")
const SCENE := "res://games/shep/enhanced/game.tscn"

const RUN_SVG := ('<svg>'
	+ '<circle fill="#00FF00" cx="100" cy="287" r="25"/>'
	+ '<circle fill="#FF0000" cx="200" cy="287" r="16.8"/>'
	+ '<rect x="365" y="252" width="70" height="70" fill="#00FF00"/>'
	+ '</svg>')

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: shep_enhanced ", msg)
	else:
		print("SMOKE FAIL: shep_enhanced ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _run() -> void:
	await _test_scene()
	await _test_direct_world_shared()
	print("shep_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("shep", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("shep", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	for i in 6:
		await process_frame
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.state == inst.TITLE and inst._cards[inst.TITLE].visible, "boots on the title card")
	_check(inst.world is World, "world is Direct shep_world.gd")
	_check(inst.world.clock_label.visible == false, "Direct in-field clock hidden (HUD owns it)")

	# Back to Arcade button present, never steals focus
	var back: Button = null
	for c in inst._ui.get_children():
		for b in c.find_children("*", "Button", true, false):
			if b.text == "Back to Arcade":
				back = b
				break
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")

	# Title -> Level Select via Play
	inst._set_state(inst.LEVEL_SELECT)
	await process_frame
	_check(inst.state == inst.LEVEL_SELECT and inst._cards[inst.LEVEL_SELECT].visible, "Play opens level select")
	_check(inst._level_buttons.size() == Levels.MENU_LEVELS, "9 level buttons")
	_check(not inst._level_buttons[0].disabled, "Level 1 unlocked")

	# Start level 1
	inst._start_level(1)
	for i in 4:
		await process_frame
	_check(inst.state == inst.GAME and inst.world.visible and not inst.world.done, "level 1 running")
	_check(inst._fuses_total == inst.world.fuses.size() and inst._fuses_total > 0, "fuse total tracked")
	_check(inst._pause_btn.visible, "in-game Pause button shown")
	_check(inst._objective.visible, "objective HUD shown")

	# Juice path: pocket sfx triggers dock burst
	var before: int = inst._particles.size()
	inst._on_world_sfx("pocket")
	_check(inst._particles.size() > before and inst._floaters.size() > 0, "pocket juice: sparks + floater")

	# Kick juice
	before = inst._particles.size()
	inst._on_kick(Vector2(100, 100))
	_check(inst._particles.size() > before, "kick juice sparks")

	# In-game pause card
	inst._pause_game()
	await process_frame
	_check(inst.state == inst.PAUSE and inst.world.paused and inst._cards[inst.PAUSE].visible, "Pause freezes the Direct world")
	inst._resume_game()
	await process_frame
	_check(inst.state == inst.GAME and not inst.world.paused, "Resume returns to play")

	# Esc -> PauseOverlay (global), freezes the tree
	var t0: float = inst.world.time_left
	root.push_input(_key(KEY_ESCAPE))
	await process_frame
	for i in 8:
		await process_frame
	_check(paused and is_equal_approx(inst.world.time_left, t0), "Esc opens PauseOverlay and freezes the clock")
	root.push_input(_key(KEY_ESCAPE))
	for i in 4:
		await process_frame
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")


## Direct World physics still wins a fuse-dock puzzle under Enhanced ownership.
func _test_direct_world_shared() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 575)
	root.add_child(vp)
	var w: World = World.new()
	vp.add_child(w)
	var result := {"won": -1}
	w.won.connect(func(secs): result["won"] = secs)
	w.svg_override = RUN_SVG
	w.start_level(0)
	_check(w.fuses.size() == 1 and w.pockets.size() == 1, "shared Direct world builds the test room")
	await physics_frame
	w.kick(Vector2(7, 0))
	var frames := 0
	while result["won"] < 0 and frames < 900:
		await physics_frame
		frames += 1
	_check(w.fuses.is_empty(), "shared world: fuse docks in the matching pocket")
	_check(result["won"] >= 100, "shared world: docking Shep wins (secs %d, frames %d)" % [result["won"], frames])
	vp.queue_free()
