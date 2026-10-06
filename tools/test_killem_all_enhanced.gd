extends SceneTree
## Headless checks for Kill 'Em All Enhanced (presentation over Direct ka_world.gd).
## Run: godot --headless --path . --script res://tools/test_killem_all_enhanced.gd

const World := preload("res://games/killem_all/direct/ka_world.gd")
const SCENE := "res://games/killem_all/enhanced/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: killem_all_enhanced ", msg)
	else:
		print("SMOKE FAIL: killem_all_enhanced ", msg)
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
	print("killem_all_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


## A scripted session through Enhanced's tick() (Direct step + presentation
## hooks) must leave exactly the state a bare Direct twin reaches.
func _test_parity_vs_direct() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	_check(inst.world.get_script() == World, "uses the Direct ka_world.gd (no rules copy)")
	var d = World.new()
	var inputs := [
		{"right": true, "mouse": Vector2(900, 200)},
		{"right": true, "up": true, "fire": true, "mouse": Vector2(900, 200)},
		{"fire": true, "mouse": Vector2(100, 700)},
		{"left": true, "down": true, "mouse": Vector2(512, 50)},
		{"mouse": Vector2(512, 50)},
		{"up": true, "fire": true, "mouse": Vector2(-200, 384)},
	]
	var same := true
	for i in 240:
		var inp: Dictionary = inputs[(i / 7) % inputs.size()]
		d.step(inp)
		inst.tick(inp)
		var w = inst.world
		same = same and w.ship_x == d.ship_x and w.ship_y == d.ship_y \
			and w.dx == d.dx and w.dy == d.dy and w.blast_angle == d.blast_angle \
			and w.fired == d.fired and w.bullets.size() == d.bullets.size() and w.steps == d.steps
		if same and not d.bullets.is_empty():
			var b0 = d.bullets[-1]
			var b1 = w.bullets[-1]
			same = b0.x == b1.x and b0.y == b1.y and b0.direction == b1.direction
	_check(same, "ship/velocity/aim/bullets match a bare Direct twin over 240 scripted steps")
	_check(inst.world.fired > 0, "scripted session fired bullets (%d)" % inst.world.fired)
	inst.free()


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("killem_all", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("killem_all", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.world.get_script() == World, "launched world is Direct logic")
	_check(not inst.playing and inst._cards["title"].visible, "boots on the title card")
	_check(inst.world.steps == 0, "title card holds the room (no steps)")
	_check(inst.world.ship_x == 512 and inst.world.ship_y == 384, "init.gml centred ship under the title")

	var back: Button = null
	var start: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			back = b
		elif b.text == "Start":
			start = b
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")
	_check(start != null, "title has a Start button")

	# Room mouse mapping: the field Control is room0 scaled into the stage.
	var field: Control = inst._field
	_check(field.clip_contents and is_equal_approx(field.size.x, World.W) and is_equal_approx(field.size.y, World.H),
		"field is a clipped 1024x768 room canvas")
	var rect := Rect2(field.position, field.size * field.scale)
	_check(Rect2(Vector2.ZERO, inst.STAGE).encloses(rect), "field fits inside the 1280x720 stage")
	var inp: Dictionary = inst._read_input()
	_check(inp.has_all(["left", "right", "up", "down", "fire", "mouse"]), "input dict matches Direct's shape")

	# Space starts play.
	root.push_input(_key(KEY_SPACE))
	root.push_input(_key(KEY_SPACE, false))
	await _frames(3)
	_check(inst.playing and not inst._cards["title"].visible, "Space leaves the title for play")
	await _frames(10)
	_check(inst.world.steps > 0, "room steps once playing (%d)" % inst.world.steps)

	# Shot juice: firing via tick() makes a muzzle flash, sparks and a rate sample.
	var p0: int = inst._particles.size()
	var f0: int = inst._flashes.size()
	inst.tick({"fire": true, "mouse": Vector2(900, 384)})
	_check(inst._flashes.size() > f0 and inst._particles.size() > p0, "fire: muzzle flash + sparks")
	_check(inst._shot_steps.size() >= 1, "fire: rate meter counts the shot")
	# Thrust juice: flame sparks while a heading is held.
	p0 = inst._particles.size()
	inst.tick({"up": true, "mouse": Vector2(900, 384)})
	_check(inst._particles.size() > p0 and inst._wake.size() > 0, "thrust: flame sparks + wake")
	# Edge ping: a bullet flying out of the room sparks on the edge.
	var pings0: int = inst._pings
	for i in 80:
		inst.tick({"mouse": Vector2(900, 384)})
	_check(inst._pings > pings0, "bullet crossing the room edge pings (%d)" % inst._pings)

	# Off-room HUD: drift the ship out (Direct has no walls) and the banner shows.
	for i in 90:
		inst.tick({"left": true, "mouse": Vector2(900, 384)})
	await _frames(2)
	_check(inst.ship_out_of_room() and inst._out_banner.visible, "off-room banner + pointer when the ship leaves")

	# R restarts room0 through Direct room_start (init.gml).
	root.push_input(_key(KEY_R))
	root.push_input(_key(KEY_R, false))
	await _frames(1)
	_check(inst.world.fired == 0 and inst.world.bullets.size() <= 1 and inst.playing,
		"R restarts room0 and stays in play")
	_check(absf(inst.world.ship_x - 512) < 40 and absf(inst.world.ship_y - 384) < 40, "R recentres the ship")

	# Esc -> PauseOverlay (tree pause), Esc again -> arcade
	var s0: int = inst.world.steps
	root.push_input(_key(KEY_ESCAPE))
	await _frames(8)
	_check(paused and inst.world.steps == s0, "Esc opens PauseOverlay and freezes the room")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
