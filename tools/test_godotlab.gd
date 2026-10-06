extends SceneTree
## Headless checks for the four godotlab Direct editions (game00, game01,
## collatz, tilemap): input moves things, the Collatz stepper is correct, and
## the tilemap level is solid enough to stand and walk on.
## Run: godot --headless --path . --script res://tools/test_godotlab.gd

const GAME00 := "res://games/godotlab_game00/direct/game.tscn"
const GAME01 := "res://games/godotlab_game01/direct/game.tscn"
const COLLATZ := "res://games/godotlab_collatz/direct/game.tscn"
const TILEMAP := "res://games/godotlab_tilemap/direct/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: godotlab ", msg)
	else:
		print("SMOKE FAIL: godotlab ", msg)
		_fail += 1


func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _load(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene


func _unload(scene: Node) -> void:
	scene.queue_free()
	await process_frame
	await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _game00()
	await _game01()
	await _collatz()
	await _tilemap()
	quit(1 if _fail else 0)


func _game00() -> void:
	var scene := _load(GAME00)
	var icon: Sprite2D = scene.get_node("icon")
	icon.wrap = false
	await _frames(2)
	var x0 := icon.position.x
	_key(KEY_RIGHT, true)
	await _frames(10)
	_key(KEY_RIGHT, false)
	_check(icon.velocity.x > 300.0, "game00 → builds velocity (vx=%.0f)" % icon.velocity.x)
	_check(icon.position.x > x0 + 20.0, "game00 → moves the sprite (dx=%.0f)" % (icon.position.x - x0))
	await _frames(240)
	_check(absf(icon.velocity.x) < 10.0, "game00 friction coasts to a stop (vx=%.1f)" % icon.velocity.x)
	icon.wrap = true
	icon.position = Vector2(-5, 200)
	await _frames(1)
	_check(icon.position.x > 1000.0, "game00 wraps at the screen edge")
	await _unload(scene)


func _game01() -> void:
	var scene := _load(GAME01)
	var hero: Sprite2D = scene.get_node("Scene/hero")
	var xhair: Sprite2D = scene.get_node("Scene/crosshair")
	await _frames(2)
	var h0 := hero.position
	var c0 := xhair.position
	_key(KEY_D, true)
	await _frames(5)
	_key(KEY_D, false)
	_check(is_equal_approx(hero.position.x - h0.x, 50.0), "game01 D (Dvorak E) moves 10 px/frame (dx=%.1f)" % (hero.position.x - h0.x))
	_check(is_equal_approx(xhair.position.x - c0.x, 50.0), "game01 crosshair drifts with the hero")
	_key(KEY_UP, true)
	await _frames(3)
	_key(KEY_UP, false)
	_check(hero.position.y < h0.y - 20.0, "game01 ↑ moves up")
	# Put the crosshair straight above the hero: the nose (art faces -x) points up.
	xhair.position = hero.position + Vector2(0, -60)
	await _frames(2)
	_check(absf(wrapf(hero.rotation - PI / 2, -PI, PI)) < 0.01, "game01 hero turns to face the crosshair (rot=%.2f)" % hero.rotation)
	await _unload(scene)


func _collatz() -> void:
	var picking0 := root.get_viewport().physics_object_picking
	root.get_viewport().physics_object_picking = false
	var scene := _load(COLLATZ)
	await process_frame
	_check(root.get_viewport().physics_object_picking, "collatz enables physics picking for the bits")
	_check(scene.bits.size() == 16, "collatz has a 16-bit register")
	_check(scene.bits.all(func(b): return b.frame == 2), "collatz bits start unset")
	# Click-toggle semantics from bit.gd: unset -> 1, then 1 <-> 0.
	var b0: Sprite2D = scene.bits[0]
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	b0._on_Area2D_input_event(null, rel, 0)
	_check(b0.frame == 1 and scene.value() == 1, "collatz click sets an unset bit")
	b0._on_Area2D_input_event(null, rel, 0)
	_check(b0.frame == 0 and scene.value() == 0, "collatz click flips 1 -> 0")
	scene.set_value(27)
	scene._restart_from_bits()
	var n := 0
	while scene.step():
		n += 1
		if n > 500:
			break
	_check(scene.value() == 1 and scene.steps == 111 and scene.peak == 9232,
		"collatz 27 reaches 1 in 111 steps, peak 9232 (got %d/%d/%d)" % [scene.value(), scene.steps, scene.peak])
	scene.set_value(6)
	scene._restart_from_bits()
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	_check(scene.value() == 3, "collatz Space steps 6 -> 3")
	scene.set_value(43691)  # 3n+1 overflows 16 bits
	scene._restart_from_bits()
	_check(not scene.step() and scene.value() == 43691, "collatz refuses to overflow the register")
	scene.clear()
	_check(scene.value() == 0, "collatz C clears")
	await _unload(scene)
	_check(root.get_viewport().physics_object_picking == false, "collatz restores physics picking on exit")
	root.get_viewport().physics_object_picking = picking0


func _tilemap() -> void:
	var scene := _load(TILEMAP)
	await process_frame
	_check(scene.placed == 48 and scene.skipped_blank == 170,
		"tilemap replays the original tile_data (placed %d, blank %d)" % [scene.placed, scene.skipped_blank])
	var p: CharacterBody2D = scene.get_node("Player")
	await _frames(60)
	_check(p.is_on_floor() and p.position.y < 300.0, "tilemap player lands on the grass (y=%.1f)" % p.position.y)
	var x0 := p.position.x
	_key(KEY_RIGHT, true)
	await _frames(20)
	_key(KEY_RIGHT, false)
	_check(p.position.x > x0 + 60.0, "tilemap → walks right (dx=%.0f)" % (p.position.x - x0))
	_key(KEY_SPACE, true)
	await _frames(8)
	_key(KEY_SPACE, false)
	_check(p.velocity.y < 0.0 and p.position.y < 270.0, "tilemap Space jumps")
	await _frames(60)
	_check(p.is_on_floor(), "tilemap player lands again")
	p.position = Vector2(100, 200)  # over the void left of the level
	await _frames(90)
	_check(p.respawns >= 1, "tilemap falling off the level respawns")
	await _unload(scene)
