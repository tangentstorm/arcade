extends SceneTree
## Headless checks for Toroidal Zombie Herder Enhanced (presentation over Direct tzh_world.gd).
## Run: godot --headless --path . --script res://tools/test_toroidal_zombie_herder_enhanced.gd

const World := preload("res://games/toroidal_zombie_herder/direct/tzh_world.gd")
const SCENE := "res://games/toroidal_zombie_herder/enhanced/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: toroidal_zombie_herder_enhanced ", msg)
	else:
		print("SMOKE FAIL: toroidal_zombie_herder_enhanced ", msg)
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
	print("toroidal_zombie_herder_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _snapshot(w) -> Array:
	var out := [w.steps, w.score, w.restarts, w.instances.size(), w.hero.x, w.hero.y]
	for z in w.of_kind(World.ZOMBIE):
		out.append_array([z.x, z.y, z.direction])
	return out


## A scripted session through Enhanced's tick() (Direct step + presentation
## hooks) must leave exactly the state a bare Direct twin reaches, including
## coin pickups and a room_restart from being caught.
func _test_parity_vs_direct() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	_check(inst.world.get_script() == World, "uses the Direct tzh_world.gd (no rules copy)")
	var d = World.new()
	var inputs := [
		{"left": true}, {"left": true, "mouse_down": true, "mouse": Vector2(100, 256)},
		{"down": true}, {}, {"right": true}, {"up": true}, {},
	]
	var same := true
	for i in 900:
		var inp: Dictionary = inputs[(i / 9) % inputs.size()] if i < 300 else {}
		d.step(inp)
		inst.tick(inp)
		same = same and _snapshot(inst.world) == _snapshot(d)
	_check(same, "hero/zombies/score/restarts match a bare Direct twin over 900 scripted steps")
	_check(d.score > 0, "scripted session collected coins (score %d)" % d.score)
	_check(d.restarts > 0 and inst._caught == d.restarts, "caught counter tracks room_restart (%d)" % inst._caught)
	inst.free()


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("toroidal_zombie_herder", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("toroidal_zombie_herder", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.world.get_script() == World, "launched world is Direct logic")
	_check(not inst.playing and inst._cards["title"].visible, "boots on the title card")
	_check(inst.world.steps == 0, "title card holds the room (no steps)")
	_check(inst.world.hero.x == 320 and inst.world.hero.y == 256, "hero waits at the room0 start")
	_check(inst._coin_total == World.Room0.INSTANCES.filter(func(r): return r[0] == "obj_coin").size(),
		"coin total read from room0 (%d)" % inst._coin_total)
	_check(inst.is_wall(Vector2i(3, 3)) and not inst.is_wall(Vector2i(10, 8)), "wall map matches room0")
	_check(inst._portals.size() > 0, "edge wrap doors found (%d)" % inst._portals.size())

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
	_check(field.clip_contents and is_equal_approx(field.size.x, World.W) and is_equal_approx(field.size.y, World.H),
		"field is a clipped 1024x768 room canvas")
	var rect := Rect2(field.position, field.size * field.scale)
	_check(Rect2(Vector2.ZERO, inst.STAGE).encloses(rect), "field fits inside the 1280x720 stage")
	var inp: Dictionary = inst._read_input()
	_check(inp.has_all(["up", "down", "left", "right", "mouse_down", "mouse"]), "input dict matches Direct's shape")

	# Wrap ghosts: a sprite near a seam is drawn on both sides.
	var offs: Array = inst.wrap_offsets(Vector2(4, 4))
	_check(offs.size() == 4 and Vector2(World.W, 0) in offs and Vector2(World.W, World.H) in offs,
		"wrap ghosts at a corner: 4 copies")
	_check(inst.wrap_offsets(Vector2(500, 400)).size() == 1, "no ghosts mid-room")

	# Space starts play.
	root.push_input(_key(KEY_SPACE))
	root.push_input(_key(KEY_SPACE, false))
	await _frames(3)
	_check(inst.playing and not inst._cards["title"].visible, "Space leaves the title for play")
	await _frames(10)
	_check(inst.world.steps > 0, "room steps once playing (%d)" % inst.world.steps)

	# Coin juice: walking left from the start collects coins.
	inst.new_run()
	var f0: int = inst._floaters.size()
	for i in 8:
		inst.tick({"left": true})
	_check(inst._pickups > 0 and inst.world.score == inst._pickups * 10, "coin pickups counted (%d)" % inst._pickups)
	_check(inst._floaters.size() > f0 and inst._particles.size() > 0, "coin: +10 floater + sparkles")

	# Trap juice: a zombie on a trap (both die in Direct) leaves goo + a banner.
	var z = inst.world.of_kind(World.ZOMBIE)[0]
	var t = inst.world.of_kind(World.TRAP)[0]
	z.x = t.x
	z.y = t.y
	inst.tick({})
	_check(inst._trapped == 1 and inst._splats.size() == 1, "trap: zombie trapped, goo splat")
	_check(inst._banner_time > 0.0, "trap: banner shown")

	# Wrap juice: the open row at y=96 wraps the hero from the left edge.
	inst.world.hero.x = 0
	inst.world.hero.y = 96
	var w0: int = inst._wraps
	inst.tick({"left": true})
	_check(inst.world.hero.x > 1000 and inst._wraps == w0 + 1, "edge wrap counted + portal rings")

	# Caught: idle until a zombie reaches the hero -> restart juice, score kept.
	var s_before: int = inst.world.score
	var c0: int = inst._caught
	var n := 0
	while inst._caught == c0 and n < 3000:
		inst.tick({})
		n += 1
	_check(inst._caught == c0 + 1 and inst._flash > 0.0, "caught: flash + counter (step %d)" % n)
	_check(inst.world.score == s_before and inst._splats.is_empty(), "caught: score kept, goo cleared")
	_check(inst.world.of_kind(World.ZOMBIE).size() == 6, "caught: room restarted (6 zombies)")
	await _frames(2)
	_check(inst._banner.visible, "caught banner visible")

	# R = new run (fresh Direct world).
	root.push_input(_key(KEY_R))
	root.push_input(_key(KEY_R, false))
	await _frames(1)
	_check(inst.world.score == 0 and inst._caught == 0 and inst.playing, "R starts a fresh run and stays in play")
	_check(inst.world.get_script() == World, "fresh run is still Direct logic")

	# Esc -> PauseOverlay (tree pause), Esc again -> arcade
	await _frames(4)
	var s0: int = inst.world.steps
	root.push_input(_key(KEY_ESCAPE))
	await _frames(8)
	_check(paused and inst.world.steps == s0, "Esc opens PauseOverlay and freezes the room")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
