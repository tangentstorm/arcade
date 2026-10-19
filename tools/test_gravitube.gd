extends SceneTree
## Headless checks for gravitube Direct.
## Run: godot --headless --path . --script res://tools/test_gravitube.gd

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: gravitube ", msg)
		_fail += 1


func _initialize() -> void:
	var scene: PackedScene = load("res://games/gravitube/direct/game.tscn")
	_check(scene != null and scene.can_instantiate(), "direct scene loads")
	var game: Node3D = scene.instantiate()
	root.add_child(game)
	await process_frame
	var port: Node3D = game.get_node("port")
	var star: Node3D = game.get_node("starboard")
	var cube: Node3D = game.get_node("starboard/Cube")
	var outer: CylinderMesh = star.get_node("Shell").mesh
	var inner: CylinderMesh = star.get_node("Shell/Inner").mesh
	_check(port.position.is_equal_approx(Vector3(0, 0, -50)) and star.position.is_equal_approx(Vector3(0, 0, 50)), "two drums at z = -50 / +50")
	_check(port.speed == -12 and star.speed == 12, "drums counter-rotate at -12 / +12 deg/s")
	_check(outer.top_radius == 33.0 and outer.height == 128.0 and not outer.cap_top and inner.top_radius == 32.0 and inner.flip_faces and not inner.cap_top, "shell: open r33 tube with an inward-facing r32 lining, length 128")
	_check(star.get_node("hub/cap").global_position.is_equal_approx(Vector3(-65, 0, 50)) and star.get_node("hub2/cap").global_position.is_equal_approx(Vector3(65, 0, 50)), "spoke caps on the drum axis at x = -65 / +65")
	var cam: Camera3D = game.get_node("Camera")
	_check(cam.current and is_equal_approx(cam.fov, 94.9) and cam.global_position.distance_to(Vector3(-2.17924, -28.0231, 50.1831)) < 0.01 and cam.environment.background_mode == Environment.BG_SKY, "source camera inside the starboard drum, sky environment")

	var y0 := cube.global_position.y
	var t := Time.get_ticks_msec()
	for i in 60:
		await physics_frame
	var secs := (Time.get_ticks_msec() - t) / 1000.0
	_check(port.rotation_degrees.x < -1.0 and star.rotation_degrees.x > 1.0 and is_equal_approx(port.rotation_degrees.x, -star.rotation_degrees.x), "drums spin in opposite directions (starboard %.1f deg after %.2fs)" % [star.rotation_degrees.x, secs])
	_check(cube.global_position.y != y0, "red cube is carried round by the drum (y %.2f -> %.2f)" % [y0, cube.global_position.y])
	var r := Vector2(cube.global_position.y, cube.global_position.z - 50.0).length()
	_check(r < 32.0, "red cube stays inside the starboard drum (r %.1f)" % r)

	game.free()
	print("VERIFY DONE: ", _fail)
	quit(_fail)
