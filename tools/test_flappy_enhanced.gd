extends SceneTree
## Headless checks for the flappy_clone enhanced edition.
## Run: godot --headless --path . --script res://tools/test_flappy_enhanced.gd

const Logic := preload("res://games/flappy_clone/enhanced/flappy_enhanced_logic.gd")
const SCENE := "res://games/flappy_clone/enhanced/game.tscn"
const DT := 1.0 / 120.0

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: flappy_enhanced ", msg)
	else:
		print("SMOKE FAIL: flappy_enhanced ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _space() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	return ev


func _esc() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	return ev


func _started() -> Logic:
	var g := Logic.new()
	g.rng.seed = 7
	g.press()
	g.press()
	return g


func _advance(g: Logic, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		g.update(DT)


func _run_until(g: Logic, seconds: float, autopilot: bool) -> void:
	var t := 0.0
	while t < seconds and g.state == Logic.State.PLAY:
		if autopilot:
			var target := 0.0
			for gate in g.gates:
				if gate.x + Logic.PIPE_HALF_W > g.bird_pos.x - Logic.HIT_RADIUS:
					target = gate.gap_y
					break
			if g.bird_pos.y < target - 0.3 and g.bird_vy < 0.5:
				g.press()
		g.update(DT)
		t += DT


func _run() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("flappy_clone", "enhanced")
	_check(entry.is_playable() and entry.scale_mode == "letterbox", "registry: enhanced playable, letterbox")
	reg.launch(entry)
	for i in 5:
		await process_frame
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.logic.state == Logic.State.TITLE, "scene boots on title")
	root.push_input(_space())
	await process_frame
	_check(inst.logic.state == Logic.State.READY, "space on title -> ready")
	root.push_input(_space())
	await process_frame
	_check(inst.logic.state == Logic.State.PLAY, "space on ready -> play")
	for i in 10:
		await process_frame
	root.push_input(_esc())
	await process_frame
	var t0: float = inst.logic.time
	for i in 10:
		await process_frame
	_check(paused and inst.logic.time == t0, "Esc pauses the run")
	root.push_input(_esc())
	for i in 3:
		await process_frame
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")

	var g := Logic.new()
	g.update(1.0)
	_check(g.state == Logic.State.TITLE and g.gates.is_empty(), "title scrolls with no pipes")
	g = _started()
	_check(is_equal_approx(g.bird_vy, Logic.FLAP_VY), "first flap sets vy to 4.4")
	g.press()
	_check(is_equal_approx(g.bird_vy, 4.4), "second flap sets vy (no 7.5 stacking)")
	_check(g.gates.size() == 1 and g.gates[0].x == 6.0 and g.gates[0].gap_y == 0.0,
		"first gate spawns at x 6 with the Direct y=0 gap")
	_advance(g, 0.5)
	_check(absf(g.bird_vy - (4.4 - 9.81 * 0.5)) < 1e-4, "gravity 9.81 (vy %.4f after 0.5 s)" % g.bird_vy)

	g = _started()
	for i in 240:
		g.press()
		g.update(DT)
	_check(g.state == Logic.State.PLAY, "ceiling is harmless")
	_check(is_equal_approx(g.bird_pos.y, Logic.CEIL_BOTTOM - Logic.BIRD_RADIUS), "ceiling clamps the bird")

	g = _started()
	_run_until(g, 12.0, true)
	_check(g.state == Logic.State.PLAY, "autopilot survives 12 s")
	_check(g.score == 6, "autopilot scores 1 per gate: %d" % g.score)
	var fair := true
	for i in range(1, g.gates.size()):
		var a = g.gates[i - 1]
		var b = g.gates[i]
		fair = fair and is_equal_approx(b.x - a.x, Logic.GATE_SPACING) \
			and b.gap_y >= Logic.GAP_MIN and b.gap_y <= Logic.GAP_MAX \
			and absf(b.gap_y - a.gap_y) <= Logic.GAP_MAX_STEP
	_check(fair and g.gates.size() >= 2, "gates spawn 5 u apart with fair gaps (%d live)" % g.gates.size())
	_check(g.gates[0].x >= Logic.DESPAWN_X - Logic.GATE_SPACING, "passed gates despawn")

	g = _started()
	g.score = 3
	g.take_events()
	g.gates[0].x = g.bird_pos.x + 0.5
	g.gates[0].gap_y = 2.0
	g.update(DT)
	_check(g.state == Logic.State.DYING and g.take_events() == [&"hit"], "pipe hit -> dying")
	var gate_x: float = g.gates[0].x
	var t := 0.0
	while g.state == Logic.State.DYING and t < 5.0:
		g.update(DT)
		t += DT
	_check(g.gates[0].x == gate_x, "world freezes while the bird falls")
	_check(g.state == Logic.State.OVER and g.landed, "bird lands, then game over (%.2f s)" % t)
	_check(is_equal_approx(g.bird_pos.y, Logic.FLOOR_TOP + Logic.BIRD_RADIUS), "bird rests on the floor")
	_check(g.take_events() == [&"land", &"over"], "land then over events")
	_check(g.best == 3 and g.new_best, "best score recorded")
	g.press()
	_check(g.state == Logic.State.OVER, "restart ignored during the lockout")
	_advance(g, Logic.RESTART_LOCK + 0.05)
	g.press()
	_check(g.state == Logic.State.READY and g.gates.is_empty() and g.bird_pos == Logic.BIRD_START,
		"tap after lockout -> ready, world reset")
	g.press()
	_check(g.score == 0, "score resets when the run starts")
	_run_until(g, 5.0, false)
	_check(g.state == Logic.State.DYING, "falling into the floor ends the run")
	_advance(g, 2.0)
	_check(g.state == Logic.State.OVER and g.best == 3 and not g.new_best, "lower score keeps best")
	quit(1 if _fail else 0)
