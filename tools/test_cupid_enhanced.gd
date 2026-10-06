extends SceneTree
## Headless checks for Cupid Enhanced (presentation over Direct cupid_logic.gd).
## Run: godot --headless --path . --script res://tools/test_cupid_enhanced.gd

const Logic := preload("res://games/cupid/direct/cupid_logic.gd")
const SCENE := "res://games/cupid/enhanced/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: cupid_enhanced ", msg)
	else:
		print("SMOKE FAIL: cupid_enhanced ", msg)
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
	print("cupid_enhanced: %s" % ("all ok" if _fail == 0 else "%d failure(s)" % _fail))
	quit(1 if _fail else 0)


## Index of the other walker carrying person i's symbol.
func _partner(g, i: int) -> int:
	for j in g.people.size():
		if j != i and g.people[j].symbol == g.people[i].symbol:
			return j
	return -1


## Index of a walker whose symbol differs from person i's (and isn't stopped).
func _stranger(g, i: int) -> int:
	for j in g.people.size():
		if j != i and g.people[j].exists and not g.people[j].stopped and g.people[j].symbol != g.people[i].symbol:
			return j
	return -1


func _hit(g, i: int) -> void:
	g.arrow_exists = true
	g._on_collision(g.people[i])


func _same(a, b) -> bool:
	if a.state != b.state or a.f != b.f or a.rng.state != b.rng.state:
		return false
	if not is_equal_approx(a.cx, b.cx) or not is_equal_approx(a.scroll_x, b.scroll_x) or a.c_right != b.c_right:
		return false
	if a.arrow_exists != b.arrow_exists or a.ax != b.ax or a.ay != b.ay or a.icon_showing != b.icon_showing:
		return false
	if a.couples_left != b.couples_left or a.clouds_left != b.clouds_left or a.rain_count() != b.rain_count():
		return false
	if a.timers.size() != b.timers.size() or a.people.size() != b.people.size():
		return false
	for i in a.people.size():
		var p = a.people[i]
		var q = b.people[i]
		if p.x != q.x or p.marked != q.marked or p.exists != q.exists or p.stopped != q.stopped \
				or p.right != q.right or p.symbol != q.symbol:
			return false
	return true


## A scripted session (mouse sweeps, clicks, a match, a mismatch, N) through
## Enhanced, with its presentation hook run after every tick, must leave the
## same Direct-owned state (rng included) as the same ticks on a bare Direct twin.
func _test_parity_vs_direct() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	_check(inst.world.get_script() == Logic, "uses the Direct cupid_logic.gd (no rules copy)")
	inst.world = Logic.new(Logic.PLAY, 7)
	var d = Logic.new(Logic.PLAY, 7)
	inst._on_world_step()
	var same := _same(inst.world, d)
	var match_i := 0
	var miss_i := -1
	for k in 1500:
		var inp := {"stage_x": 328.0 + 300.0 * sin(k * 0.01), "stage_y": 120.0, "click": k % 45 == 0,
				"next_level": k == 1300}
		d.step(inp)
		inst.world.step(inp)
		inst._on_world_step()
		inst._animate(Logic.DT)
		if k == 200:
			while d.people[match_i].stopped or d.people[_partner(d, match_i)].stopped:
				match_i += 1
			var mate := _partner(d, match_i)
			for g in [d, inst.world]:
				g.last_hit = null
				_hit(g, match_i)
				_hit(g, mate)
			inst._on_world_step()
		if k == 600:
			miss_i = 0
			while not d.people[miss_i].exists or d.people[miss_i].stopped:
				miss_i += 1
			var other := _stranger(d, miss_i)
			for g in [d, inst.world]:
				g.last_hit = null
				_hit(g, miss_i)
				_hit(g, other)
			inst._on_world_step()
		same = same and _same(inst.world, d)
	_check(same, "Direct state (rng, cupid, camera, arrow, walkers, storm) matches a bare Direct twin over 1500 ticks")
	_check(d.couples_left < Logic.NUM_COUPLES,
		"scripted session made at least one couple")
	_check(inst._arrows > 0, "Enhanced counted arrows from Direct arrow state")
	inst.free()


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("cupid", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("cupid", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.world.get_script() == Logic, "launched world is Direct logic")
	_check(inst.world.state == Logic.TITLE and inst._cards["title"].visible, "boots on the title card")
	_check(inst._field.size == Vector2(Logic.STAGE_W, Logic.STAGE_H) and inst._field.clip_contents,
		"field is the 656x350 Direct stage, clipped")

	var back: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			back = b
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")

	# Space starts play through the Direct title latch.
	root.push_input(_key(KEY_SPACE))
	root.push_input(_key(KEY_SPACE, false))
	await _frames(4)
	var w = inst.world
	_check(w.state == Logic.PLAY and not inst._cards["title"].visible, "Space leaves the title for play")

	# Keep every walker far from cupid's drop line so the test arrow lands on the street.
	for p in w.people:
		p.x = 1700.0 if w.cx < 900 else 0.0
		p.stopped = true
	var a0: int = inst._arrows
	var m0: int = inst._misses
	w.step({"stage_x": w.cx + w.scroll_x, "stage_y": 100.0, "click": true})
	inst._on_world_step()
	_check(w.arrow_exists and inst._arrows == a0 + 1, "click fires a Direct arrow; Enhanced counts it")
	for i in 90:
		w.step({"stage_x": w.cx + w.scroll_x, "stage_y": 100.0})
		inst._on_world_step()
	_check(not w.arrow_exists and inst._misses == m0 + 1, "arrow hitting the street counts a miss")
	for p in w.people:
		p.stopped = false

	# First hit: bubble pop + "1 of 2" + the pending-pick pill source.
	var p0 = w.people[0]
	var f0: int = inst._floaters.size()
	_hit(w, 0)
	inst._on_world_step()
	_check(inst._pops.has(p0) and inst._floaters.size() > f0 and w.last_hit == p0, "first hit: bubble pop + 1-of-2 floater")

	# Second hit with the same symbol: MATCH juice (hearts, floater, icon).
	var j := _partner(w, 0)
	var parts: int = inst._particles.size()
	_hit(w, j)
	inst._on_world_step()
	var matched := false
	for f in inst._floaters:
		matched = matched or f.text == "MATCH!"
	_check(matched and inst._particles.size() > parts and inst._icon_t.good >= 0.0, "match: hearts + MATCH! + heart icon")

	# After Direct's 1.5 s timer the couple dissolves into ghosts.
	for i in 140:
		w.step({"stage_x": 300.0, "stage_y": 100.0})
		inst._on_world_step()
	_check(not p0.exists and inst._ghosts.size() >= 2 and w.couples_left == Logic.NUM_COUPLES - 1,
		"matched couple dissolves (Direct exists=false -> ghosts)")
	var c0: float = inst._clear
	inst._animate(1.0)
	_check(inst._clear > c0, "sky warms as the Direct storm loses a cloud")

	# Mismatch: no-match floater and breaking-heart icon; both walk on.
	var a := _stranger(w, -1)
	var b := _stranger(w, a)
	_hit(w, a)
	_hit(w, b)
	inst._on_world_step()
	var nomatch := false
	for f in inst._floaters:
		nomatch = nomatch or f.text == "no match"
	_check(nomatch and inst._icon_t.bad >= 0.0, "mismatch: no-match floater + breaking-heart icon")
	for i in 140:
		w.step({"stage_x": 300.0, "stage_y": 100.0})
		inst._on_world_step()
	_check(not w.people[a].stopped and not w.people[b].stopped, "mismatched walkers resume (Direct timer)")

	# Esc -> PauseOverlay (tree pause freezes the sim), Esc again resumes path -> arcade.
	var fr: int = w.f
	root.push_input(_key(KEY_ESCAPE))
	await _frames(8)
	_check(paused and w.f == fr and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"Esc opens PauseOverlay, freezes the sim, shows the OS cursor")
	get_root().get_node("PauseOverlay")._resume()
	await _frames(2)

	# Finish the remaining couples: win card + best time.
	for sym in Logic.NUM_COUPLES:
		var pair: Array = []
		for i in w.people.size():
			if w.people[i].exists and w.people[i].symbol == sym:
				pair.append(i)
		if pair.size() == 2:
			w.last_hit = null
			_hit(w, pair[0])
			_hit(w, pair[1])
			inst._on_world_step()
			for i in 140:
				w.step({"stage_x": 300.0, "stage_y": 100.0})
				inst._on_world_step()
	_check(w.state == Logic.WON and inst._cards["win"].visible, "five couples: Direct WON + win card")
	_check(inst._best > 0.0 and inst._won_time > 0.0, "win records a clear time / best")

	# Space restarts through Direct; the card hides and juice resets.
	w.step({"start": true})
	inst._on_world_step()
	_check(w.state == Logic.PLAY and not inst._cards["win"].visible and inst._arrows == 0, "Space plays again")

	root.push_input(_key(KEY_ESCAPE))
	await _frames(6)
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc twice -> back to the arcade")
