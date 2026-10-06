extends SceneTree
## Headless checks for Canyon Run Enhanced (presentation over Direct canyon_logic.gd).
## Run: godot --headless --path . --script res://tools/test_canyon_run_enhanced.gd

const Logic := preload("res://games/canyon_run/direct/canyon_logic.gd")
const SCENE := "res://games/canyon_run/enhanced/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: canyon_run_enhanced ", msg)
	else:
		print("SMOKE FAIL: canyon_run_enhanced ", msg)
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
	print("canyon_run_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


## A scripted session through Enhanced tick() must leave the same Direct-owned
## state as the same steps on a bare Logic twin (same seed).
func _test_parity_vs_direct() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	_check(inst.logic.get_script() == Logic, "uses the Direct canyon_logic.gd (no rules copy)")
	inst.logic = Logic.new(42)
	var d = Logic.new(42)
	inst.playing = true
	inst._show_card("")
	var inputs := [
		{"steer": 0.0, "throttle": 0.0, "fire": true},
		{"steer": -1.0, "throttle": 1.0, "fire": false},
		{"steer": 1.0, "throttle": -1.0, "fire": true},
		{"steer": 0.0, "throttle": 1.0, "fire": true},
		{"steer": -0.5, "throttle": 0.0, "fire": false},
		{"steer": 0.5, "throttle": 0.0, "fire": true},
	]
	var same := true
	var dt := 1.0 / 60.0
	for i in 180:
		var inp: Dictionary = inputs[(i / 5) % inputs.size()]
		# Mirror Enhanced's fire → restart_if_ready / fire path on the twin.
		if inp.fire:
			if not d.restart_if_ready():
				d.fire()
		d.update(dt, inp.steer, inp.throttle)
		inst.tick(dt, inp.steer, inp.throttle, inp.fire)
		var g = inst.logic
		same = same and is_equal_approx(g.player_x, d.player_x) \
			and is_equal_approx(g.dist, d.dist) \
			and is_equal_approx(g.speed, d.speed) \
			and g.score == d.score and g.kills == d.kills \
			and g.state == d.state \
			and g.bullets.size() == d.bullets.size() \
			and g.enemies.size() == d.enemies.size()
	_check(same, "craft/dist/speed/score/kills/state/bullets/enemies match Direct over 180 ticks")
	_check(inst.logic.dist > 0.0, "scripted session flew some distance (%.1f)" % inst.logic.dist)
	inst.free()


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("canyon_run", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("canyon_run", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.logic.get_script() == Logic, "launched logic is Direct canyon_logic.gd")
	_check(not inst.playing and inst._cards["title"].visible, "boots on the title card")
	_check(inst.logic.state == Logic.State.READY and inst.logic.dist == 0.0, "title holds READY (no scroll)")

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
	_check(is_equal_approx(field.size.x, Logic.STAGE_W * inst.PX) \
		and is_equal_approx(field.size.y, Logic.STAGE_H * inst.PX),
		"field is 240×320 @2× (480×640)")
	_check(Rect2(Vector2.ZERO, inst.STAGE).encloses(Rect2(field.position, field.size)),
		"field fits inside the 1280×720 stage")

	# Space starts play.
	root.push_input(_key(KEY_SPACE))
	root.push_input(_key(KEY_SPACE, false))
	await _frames(3)
	_check(inst.playing and not inst._cards["title"].visible, "Space leaves the title for play")
	_check(inst.logic.state == Logic.State.PLAY, "Direct logic enters PLAY")

	# Fly a bit via tick; exhaust / trail juice.
	var p0: int = inst._particles.size()
	for i in 20:
		inst.tick(1.0 / 60.0, 0.0, 1.0, false)
	await _frames(2)
	_check(inst.logic.dist > 0.0 and inst.logic.speed > Logic.SPEED_CRUISE - 1.0,
		"throttle up advances dist/speed")
	_check(inst._particles.size() > p0 or inst._trail.size() > 0, "exhaust / trail juice while flying")

	# Fire juice: a new bullet triggers muzzle particles + small shake.
	inst.logic.bullets.clear()
	inst._prev_bullets = 0
	var f0: int = inst._particles.size()
	inst.tick(1.0 / 60.0, 0.0, 0.0, true)
	_check(inst.logic.bullets.size() >= 1, "fire spawns a Direct bullet")
	_check(inst._particles.size() > f0 or inst._shake > 0.0, "fire: muzzle juice / shake")

	# Kill juice: place a drifter ahead and let a bullet hit it.
	inst.logic.enemies = [{"pos": Vector2(inst.logic.player_x, inst.logic.player_world_y() + 50.0), "vx": 0.0}]
	var bs: Array[Vector2] = [Vector2(inst.logic.player_x, inst.logic.player_world_y() + 10.0)]
	inst.logic.bullets = bs
	inst._prev_kills = inst.logic.kills
	var k0: int = inst.logic.kills
	var float0: int = inst._floaters.size()
	for i in 40:
		inst.tick(1.0 / 60.0, 0.0, 0.0, false)
		if inst.logic.kills > k0:
			break
	_check(inst.logic.kills > k0, "bullet destroys a drifter through Direct logic")
	_check(inst._floaters.size() > float0 or inst._particles.size() > 0, "kill: +50 floater / burst juice")

	# Crash into the left wall → crash card + shake.
	inst.logic.enemies.clear()
	for i in 120:
		inst.tick(1.0 / 60.0, -1.0, 0.0, false)
		if inst.logic.state == Logic.State.CRASHED:
			break
	await _frames(2)
	_check(inst.logic.state == Logic.State.CRASHED, "hitting the canyon wall crashes")
	_check(inst._cards["crash"].visible, "crash card shows")
	_check(inst._shake > 0.0 or inst._flash > 0.0, "crash: shake / flash juice")

	# Esc → PauseOverlay (tree pause), Esc again → arcade
	var d0: float = inst.logic.dist
	root.push_input(_key(KEY_ESCAPE))
	await _frames(8)
	_check(paused and is_equal_approx(inst.logic.dist, d0), "Esc opens PauseOverlay and freezes the run")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
