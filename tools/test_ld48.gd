extends SceneTree
## Headless scene checks for the ld48 direct port: Ernie lands, walks, jumps;
## the room0 dialog script plays through (0 key fast-forwards, as in the
## original); holding E on the teleporter warps to Ivan's office.
## Run: godot --headless --path . --script res://tools/test_ld48.gd

const ROOM0 := "res://games/ld48/direct/game.tscn"
const OFFICE := "res://games/ld48/direct/ivan_office.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ld48 ", msg)
	else:
		print("SMOKE FAIL: ld48 ", msg)
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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load(ROOM0).instantiate()
	root.add_child(scene)
	current_scene = scene
	var ernie: CharacterBody2D = scene.get_node("room/sprites/ernie")
	var room: Node = scene.get_node("room")
	var chat: Node = scene.get_node("camshaker/camera/sidebar/vbox/chatroom/vbox")
	await process_frame  # room0 starts its script deferred
	await process_frame
	_check(not ernie.has_teleporter, "room0 disables the teleporter beam")
	_check(not scene.get_node("camshaker/camera/sidebar").visible, "chat sidebar hidden during the quake")
	_check(scene.get_node("camshaker").shake > 0, "room opens with a camera shake")

	await _frames(90)
	_check(ernie.is_on_floor(), "Ernie lands on the tile floor (y=%.1f)" % ernie.position.y)
	var y0 := ernie.position.y
	var x0 := ernie.position.x
	_key(KEY_A, true)
	await _frames(30)
	_key(KEY_A, false)
	_check(ernie.position.x < x0 - 40, "A walks left (dx=%.1f)" % (ernie.position.x - x0))
	await _frames(10)
	x0 = ernie.position.x
	_key(KEY_D, true)
	await _frames(30)
	_key(KEY_D, false)
	_check(ernie.position.x > x0 + 20, "D walks right (dx=%.1f)" % (ernie.position.x - x0))
	await _frames(20)
	_key(KEY_SPACE, true)
	var min_y := ernie.position.y
	for i in 30:
		await physics_frame
		min_y = minf(min_y, ernie.position.y)
	_key(KEY_SPACE, false)
	_check(min_y < y0 - 30, "Space jumps (rise=%.1f)" % (y0 - min_y))
	await _frames(90)
	_check(ernie.is_on_floor(), "Ernie lands again after the jump")

	# Fast-forward the dialog with the original's debug key 0.
	_key(KEY_0, true)
	var t := 0.0
	var teleporter: RigidBody2D = scene.get_node("room/sprites/teleporter")
	var tele_y0 := teleporter.position.y
	while t < 8.0 and chat.get_child_count() < 11:
		await process_frame
		t += get_root().get_process_delta_time()
	_key(KEY_0, false)
	_check(scene.get_node("camshaker/camera/sidebar").visible, "chat sidebar shown after the quake")
	_check(chat.get_child_count() == 11, "all 11 dialog lines posted (%d)" % chat.get_child_count())
	await _frames(30)
	_check(teleporter.position.y > tele_y0 + 20, "teleporter released (falls) at the end of the dialog")

	# Hold E on the teleporter for > 3 s: warp to Ivan's office.
	ernie.focus = teleporter
	_key(KEY_E, true)
	t = 0.0
	while t < 5.0 and is_instance_valid(scene) and current_scene == scene:
		await process_frame
		t += get_root().get_process_delta_time()
	_key(KEY_E, false)
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.scene_file_path == OFFICE,
		"holding E on the teleporter warps to Ivan's office")

	if current_scene and current_scene.scene_file_path == OFFICE:
		var e2: CharacterBody2D = current_scene.get_node("ernie")
		_check(e2.has_teleporter, "teleporter beam enabled in Ivan's office")
		await _frames(90)
		_check(e2.is_on_floor(), "Ernie lands in Ivan's office (y=%.1f)" % e2.position.y)
		# Teleport: beam on, aim at open air, fire.
		var target := e2.global_position + Vector2(-200, -150)
		e2.get_node("beam").visible = true
		e2.obstructed = false
		e2.fire(target)
		_check(e2.global_position.is_equal_approx(target), "left-click with clear beam teleports")
		current_scene.queue_free()
	await process_frame
	quit(1 if _fail else 0)
