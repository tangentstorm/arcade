extends SceneTree
## Headless checks for the shep direct port (tangentstorm/shep, Haxe/Flash).
## Run: godot --headless --path . --script res://tools/test_shep.gd

const Levels := preload("res://games/shep/direct/shep_levels.gd")
const World := preload("res://games/shep/direct/shep_world.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: shep ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_levels()
	_test_rules()
	await _test_physics()
	print("shep: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


func _test_levels() -> void:
	# counts straight from the SVGs: [fuses code0, fuses code1, pockets code0,
	# pockets code1, doors, spinners, floaters, wall polys, wall rects]
	var expect := {
		0: [3, 0, 3, 0, 0, 0, 0, 3, 0],
		1: [3, 0, 2, 0, 0, 0, 0, 7, 4],
		2: [3, 0, 2, 0, 0, 0, 6, 32, 0],
		3: [4, 0, 4, 0, 0, 0, 7, 0, 0],
		4: [3, 0, 1, 0, 0, 1, 0, 0, 4],
		5: [3, 1, 1, 1, 1, 2, 0, 14, 5],
		6: [4, 0, 1, 0, 0, 4, 0, 3, 0],
		7: [2, 2, 1, 1, 0, 0, 0, 8, 0],
		8: [1, 1, 1, 1, 1, 0, 1, 1, 0],
		9: [7, 8, 3, 3, 0, 0, 0, 0, 0],
	}
	for n in Levels.LEVEL_COUNT:
		var lv := Levels.parse_level(n)
		var got := [
			Levels.count_kind(lv, Levels.FUSE, 0), Levels.count_kind(lv, Levels.FUSE, 1),
			Levels.count_kind(lv, Levels.POCKET, 0), Levels.count_kind(lv, Levels.POCKET, 1),
			Levels.count_kind(lv, Levels.DOOR), Levels.count_kind(lv, Levels.SPINNER),
			Levels.count_kind(lv, Levels.FLOATER), Levels.count_kind(lv, Levels.WALL_POLY),
			Levels.count_kind(lv, Levels.WALL_RECT),
		]
		_check(got == expect[n], "level %04d.svg parses to %s (got %s)" % [n, expect[n], got])
		_check(lv["start"] != Levels.DEFAULT_START, "level %d has a green start circle" % n)
		var bad := 0
		for it in lv["items"]:
			if it.has("points"):
				for p in it["points"]:
					if not (is_finite(p.x) and is_finite(p.y)):
						bad += 1
		_check(bad == 0, "level %d polygon vertices are all finite" % n)
	var l0 := Levels.parse_level(0)
	_check(l0["start"].is_equal_approx(Vector2(73.5, 73)), "0000.svg start at (73.5, 73)")
	var l3 := Levels.parse_level(3)
	var cargo := 0
	for it in l3["items"]:
		if it["kind"] == Levels.FLOATER and it["clip"] == "cargo":
			cargo += 1
	_check(cargo == 7, "0003.svg's 8-sided magenta polygons are cargo boxes")
	var l4 := Levels.parse_level(4)
	for it in l4["items"]:
		if it["kind"] == Levels.SPINNER:
			_check(it["horizontal"] and it["pos"].is_equal_approx(Vector2(399.5, 290.5)),
				"0004.svg spinner is horizontal at (399.5, 290.5)")
	# only direct children of <svg> count; <line>s and <polyline>s are ignored
	var tiny := Levels.parse_svg('<svg><g><rect x="0" y="0" width="5" height="5" fill="#FFFFFF"/></g>'
		+ '<polyline fill="#00FFFF" points="0,0 10,0 10,10"/><circle fill="#00FF00" cx="5" cy="6" r="25"/></svg>')
	_check(tiny["items"].is_empty() and tiny["start"] == Vector2(5, 6), "nested rects and polylines are skipped")


func _test_rules() -> void:
	var ords := []
	for i in range(1, 10):
		ords.append(Levels.ord_level(i))
	_check(ords == [0, 1, 3, 9, 4, 6, 7, 5, 2], "ordLevel maps menu 1..9 to svgs %s" % [ords])
	_check(Levels.level_name(4) == "BREAK ROOM", "level names from console.mxml")
	_check(Levels.clock_text(120) == "02:00" and Levels.clock_text(59) == "00:59", "FlashClock MM:SS")
	_check(Levels.time_count(119.2) == 120 and Levels.time_count(-3.0) == 0, "timeCount = ceil, floored at 0")
	_check(Levels.alert_for(31) == "" and Levels.alert_for(30) == "alert1" and Levels.alert_for(20) == "alert2"
		and Levels.alert_for(10) == "alert3" and Levels.alert_for(5) == "alert3x2", "red alert thresholds")
	var s := {}
	_check(Levels.is_unlocked(1, s) and not Levels.is_unlocked(2, s), "only Level 1 open with no scores")
	_check(Levels.record_score(s, 0, 80), "first score saved")
	_check(Levels.is_unlocked(2, s) and not Levels.is_unlocked(3, s), "beating svg 0 unlocks Level 2")
	_check(not Levels.record_score(s, 0, 70) and s[0] == 80, "slower time does not replace best")
	_check(Levels.record_score(s, 0, 95) and s[0] == 95, "faster time (more seconds left) replaces best")
	_check(Levels.best_time_text(0, s) == "Best Time: 25 seconds", "best time = 120 - seconds left")
	_check(Levels.best_time_text(1, s) == "No Best Time Yet!", "no best time text")
	_check(not Levels.shows_trophy(s) and Levels.shows_trophy({9: 1}), "trophy keyed to raw_score(9)")
	var v := Levels.calc_vector(Vector2(0, 0), Vector2(30, 40), 50.0)
	_check(is_equal_approx(v.length(), sqrt(50.0)) and v.normalized().is_equal_approx(Vector2(0.6, 0.8)),
		"calcVector: length sqrt(r) toward the mouse")
	_check(is_equal_approx(Levels.aim_rotation_deg(Vector2(1, 0)), 90.0)
		and is_equal_approx(Levels.aim_rotation_deg(Vector2(-1, 0)), 270.0)
		and Levels.aim_rotation_deg(Vector2(0, -3)) == 0.0, "drawVector rotation")
	_check(Levels.facing(0.0).is_equal_approx(Vector2(0, -1)) and Levels.facing(90.0).is_equal_approx(Vector2(1, 0)),
		"shepClipVector: sprite faces up at rotation 0")


## A tiny room: Shep, one plain fuse, one green pocket, all on a line.
const RUN_SVG := ('<svg>'
	+ '<circle fill="#00FF00" cx="100" cy="287" r="25"/>'
	+ '<circle fill="#FF0000" cx="200" cy="287" r="16.8"/>'
	+ '<rect x="365" y="252" width="70" height="70" fill="#00FF00"/>'
	+ '</svg>')
## Red fuse into the cyan pocket opens the door.
const DOOR_SVG := ('<svg>'
	+ '<circle fill="#00FF00" cx="100" cy="100" r="25"/>'
	+ '<circle fill="#00FFFF" cx="200" cy="287" r="16.8"/>'
	+ '<rect x="365" y="252" width="70" height="70" fill="#00FFFF"/>'
	+ '<rect x="600" y="200" width="20" height="145" fill="#009999"/>'
	+ '</svg>')


func _make_world() -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 575)
	root.add_child(vp)
	var w: World = World.new()
	vp.add_child(w)
	return [vp, w]


func _test_physics() -> void:
	var pair := _make_world()
	var vp: SubViewport = pair[0]
	var w: World = pair[1]
	_check(w.get_world_2d() != root.world_2d, "world runs in its own physics space")
	var result := {"won": -1, "lost": false, "sfx": []}
	w.won.connect(func(secs): result["won"] = secs)
	w.lost.connect(func(): result["lost"] = true)
	w.sfx.connect(func(n): result["sfx"].append(n))
	w.svg_override = RUN_SVG
	w.start_level(0)
	_check(w.fuses.size() == 1 and w.pockets.size() == 1, "custom room built: 1 fuse, 1 pocket")
	await physics_frame
	w.kick(Vector2(7, 0))   # calcVector(50) is ~7.07 px/frame
	var frames := 0
	while result["won"] < 0 and frames < 900:
		await physics_frame
		frames += 1
	_check(w.fuses.is_empty(), "the fuse went into the matching pocket")
	_check(result["sfx"].has("pocket") and result["sfx"].has("fuse"), "pocket and fuse sounds fired %s" % [result["sfx"]])
	_check(result["won"] >= 100, "docking Shep after the last fuse wins (secs left %d, %d frames)" % [result["won"], frames])
	_check(w.done, "world stops after the win")

	# a fuse in the wrong-colored pocket just bounces
	w.svg_override = DOOR_SVG
	w.start_level(0)
	_check(w.doors.size() == 1, "door built from the dark-cyan rect")
	var fuse: RigidBody2D = w.fuses[0]["body"]
	fuse.linear_velocity = Vector2(7, 0) * World.FPS
	frames = 0
	while not w.fuses.is_empty() and frames < 600:
		await physics_frame
		frames += 1
	_check(w.fuses.is_empty() and w.doors.is_empty(), "red fuse in the red pocket opens the door")
	_check(result["sfx"].has("door"), "door sound")

	# running out of time loses
	result["lost"] = false
	w.start_level(0)
	w.time_left = 0.05
	for i in 10:
		await physics_frame
	_check(result["lost"] and w.done, "clock reaching 00:00 loses")

	# pause freezes the clock
	w.start_level(0)
	w.pause()
	var t := w.time_left
	for i in 10:
		await physics_frame
	_check(w.time_left == t, "paused world keeps its clock")
	w.resume()
	vp.queue_free()
	await process_frame
