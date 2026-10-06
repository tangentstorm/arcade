extends SceneTree
## Headless checks for oK Defender Enhanced (presentation over Direct logic).
## Run: godot --headless --path . --script res://tools/test_ok_defender_enhanced.gd

const Logic := preload("res://games/ok_defender/direct/ok_defender_logic.gd")
const SCENE := "res://games/ok_defender/enhanced/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ok_defender_enhanced ", msg)
	else:
		print("SMOKE FAIL: ok_defender_enhanced ", msg)
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
	await _test_scene()
	print("ok_defender_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


## A scripted input session through Enhanced must leave the same Direct-owned
## world state as the same steps on a twin Logic instance.
func _test_parity_vs_direct() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	_check(inst.world.get_script() == Logic, "uses the Direct ok_defender_logic.gd (no rules copy)")
	# Rebuild both worlds from the same seed so terrain/aliens match.
	inst.world = Logic.new(Logic.PLAY, 11)
	var d = Logic.new(Logic.PLAY, 11)
	_check(inst.world.world_w == d.world_w and inst.world.hu.size() == d.hu.size(),
		"seeded Enhanced world matches Direct twin")
	var inputs := [
		{"dx": 1, "dy": 0, "fire": false},
		{"dx": 1, "dy": 0, "fire": true},
		{"dx": 0, "dy": -1, "fire": true},
		{"dx": -1, "dy": 0, "fire": true},
		{"dx": 0, "dy": 1, "fire": false},
		{"dx": 0, "dy": 0, "fire": true},
	]
	var same := true
	for step_i in 90:
		var inp: Dictionary = inputs[step_i % inputs.size()]
		d.step(inp)
		inst.world.step(inp)
		same = same and is_equal_approx(d.sh.x, inst.world.sh.x) \
			and is_equal_approx(d.sh.y, inst.world.sh.y) \
			and d.kills == inst.world.kills \
			and d.saved == inst.world.saved \
			and d.lost == inst.world.lost \
			and d.carried == inst.world.carried \
			and d.ph.size() == inst.world.ph.size() \
			and d.al.size() == inst.world.al.size() \
			and d.state == inst.world.state
	_check(same, "ship/score/phasers/aliens/state match Direct after 90 scripted ticks")
	inst.free()


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("ok_defender", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("ok_defender", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.world.get_script() == Logic, "launched world is Direct logic")
	_check(inst.world.state == Logic.TITLE and inst._cards["title"].visible, "boots on the title card")

	var back: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			back = b
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")

	# Space starts play (Direct latch). Inject held Space across a few process ticks.
	# Force a start the same way Direct title does: call step with fire.
	inst.world.step({"fire": true})
	inst._on_world_step()
	await _frames(2)
	_check(inst.world.state == Logic.PLAY and not inst._cards["title"].visible, "Space/start leaves title for play")

	# Juice path: bump kills and run the presentation hook.
	var before: int = inst._particles.size()
	var kills0: int = inst.world.kills
	inst._prev.kills = kills0
	inst.world.kills = kills0 + 1
	inst._on_world_step()
	_check(inst._particles.size() > before and inst._floaters.size() > 0, "kill juice: particles + floater")

	# Catch juice
	before = inst._particles.size()
	var c0: int = inst.world.carried
	inst._prev.carried = c0
	inst.world.carried = c0 + 1
	inst._on_world_step()
	_check(inst._particles.size() > before, "catch juice: particles")

	# Esc -> PauseOverlay (tree pause), Esc again -> arcade
	var f0: int = inst.world.f
	root.push_input(_key(KEY_ESCAPE))
	await _frames(8)
	_check(paused and inst.world.f == f0, "Esc opens PauseOverlay and freezes the sim")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
