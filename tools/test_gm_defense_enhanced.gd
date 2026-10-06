extends SceneTree
## Headless checks for GM Defense Enhanced (presentation over Direct gmd_world.gd).
## Run: godot --headless --path . --script res://tools/test_gm_defense_enhanced.gd

const World := preload("res://games/gm_defense/direct/gmd_world.gd")
const SCENE := "res://games/gm_defense/enhanced/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: gm_defense_enhanced ", msg)
	else:
		print("SMOKE FAIL: gm_defense_enhanced ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, pressed := true, echo := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.echo = echo
	return ev


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var probe = (load(SCENE) as PackedScene).instantiate() if load(SCENE) is PackedScene else null
	var ok: bool = probe != null and probe.get_script() != null and probe.get_script().can_instantiate()
	_check(ok, "enhanced/game.gd compiles and attaches")
	if probe:
		probe.free()
	if not ok:
		quit(1)
		return
	_test_parity_vs_direct()
	await _test_scene()
	print("gm_defense_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _same(a, b) -> bool:
	for p in [[a.ship, b.ship], [a.squid, b.squid]]:
		var i = p[0]
		var j = p[1]
		if not is_equal_approx(i.x, j.x) or not is_equal_approx(i.y, j.y) or i.direction != j.direction \
				or i.image_xscale != j.image_xscale or not is_equal_approx(i.image_index, j.image_index) \
				or i.speed != j.speed:
			return false
	return a.steps == b.steps


## A scripted key session fed through Enhanced's own input path and fixed-step
## loop (presentation hooks included) must leave the same Direct-owned state as
## the same Key Press edges on a bare Direct twin, every step.
func _test_parity_vs_direct() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	inst.set_process(false)
	inst.set_process_unhandled_input(false)
	_check(inst.world.get_script() == World, "uses the Direct gmd_world.gd (no rules copy)")
	var d = World.new()
	_check(_same(inst.world, d), "starts identical to Direct (ship 320,416; squid 352,288)")
	var same := true
	var went_off := false
	var came_back := false
	var turns := 0
	var prev_x: float = d.ship.image_xscale
	for k in 1200:
		var left := k in [40, 41, 300, 700, 1001]
		var right := k in [150, 151, 520, 900, 1001]
		if left:
			inst._unhandled_input(_key(KEY_LEFT))
			inst._unhandled_input(_key(KEY_LEFT, true, true))  # echo must be ignored
		if right:
			inst._unhandled_input(_key(KEY_RIGHT))
		inst._unhandled_input(_key(KEY_LEFT, false))  # releases do nothing
		d.step({"left_pressed": left, "right_pressed": right})
		inst._process(inst.STEP_SEC)
		same = same and _same(inst.world, d)
		if d.ship.image_xscale != prev_x:
			turns += 1
			prev_x = d.ship.image_xscale
		if not d.ship_on_screen():
			went_off = true
		elif went_off:
			came_back = true
	_check(same, "ship/squid/steps match Direct after every one of 1200 steps")
	_check(went_off and came_back, "session covers leaving the room and coming back")
	_check(inst._turns == turns and turns >= 6, "turn juice counted every Direct flip (%d/%d)" % [inst._turns, turns])
	_check(inst._exits >= 1, "room exits counted (%d)" % inst._exits)
	inst.free()


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("gm_defense", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("gm_defense", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.world.get_script() == World, "launched world is Direct logic")
	_check(inst.world.steps > 0 and inst.world.ship.x > 320, "ship launches on frame one, like Direct")

	var back: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			back = b
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")

	# Real key event through the tree turns the ship and fires turn juice.
	var t0: int = inst._turns
	root.push_input(_key(KEY_LEFT))
	await _frames(4)
	_check(inst.world.ship.image_xscale == -1 and inst._turns == t0 + 1, "Left key turns ship (Direct) + turn juice")
	_check(inst._rings.size() > 0 and inst._floaters.size() > 0, "turn ring + floater")
	root.push_input(_key(KEY_LEFT, false))

	# Off-room locator: push the Direct ship out and check the view reports it.
	inst.world.ship.x = World.W + 300
	_check(not inst.world.ship_on_screen() and is_equal_approx(inst.off_distance(), 275.0),
		"off-room distance from the sprite edge (%s)" % inst.off_distance())
	inst.world.ship.x = 500
	_check(inst.off_distance() == 0.0, "no locator while in the room")

	# Esc -> PauseOverlay (tree pause), Esc again -> arcade.
	var s0: int = inst.world.steps
	root.push_input(_key(KEY_ESCAPE))
	await _frames(8)
	_check(paused and inst.world.steps == s0, "Esc opens PauseOverlay and freezes the sim")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
