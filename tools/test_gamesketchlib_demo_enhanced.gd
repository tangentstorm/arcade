extends SceneTree
## Headless checks for GameSketchLib Demo Enhanced (presentation over Direct gsl_demo_logic.gd).
## Run: godot --headless --path . --script res://tools/test_gamesketchlib_demo_enhanced.gd

const Logic := preload("res://games/gamesketchlib_demo/direct/gsl_demo_logic.gd")
const SCENE := "res://games/gamesketchlib_demo/enhanced/game.tscn"

var _fail := 0
var _ok := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("ok: gamesketchlib_demo_enhanced ", msg)
	else:
		print("SMOKE FAIL: gamesketchlib_demo_enhanced ", msg)
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
	_test_no_rules_copy()
	_test_parity_vs_direct()
	await _test_scene()
	print("gamesketchlib_demo_enhanced: %s (%d checks)" % ["all ok" if _fail == 0 else "%d failure(s)" % _fail, _ok + _fail])
	quit(1 if _fail else 0)


func _test_no_rules_copy() -> void:
	var src := FileAccess.get_file_as_string("res://games/gamesketchlib_demo/enhanced/game.gd")
	_check(src.find("func step(") < 0 and src.find("func _overlap(") < 0 \
			and src.find("func switch_state(") < 0 and src.find("func mouse_pressed(") < 0 \
			and src.find("K_BULLET_SPEED :=") < 0 and src.find("class Obj") < 0,
			"enhanced/ defines no rules (step/_overlap/switch_state/mouse_pressed/Obj/speed)")
	_check(src.find('preload("res://games/gamesketchlib_demo/direct/gsl_demo_logic.gd")') >= 0,
			"enhanced preloads Direct gsl_demo_logic.gd")
	_check(src.find("world.render()") >= 0, "enhanced paints Direct's render list")


func _snapshot(w) -> Array:
	var out: Array = [w.state, w.bg]
	for sq in w.squares:
		out.append([sq.x, sq.y, sq.alive, sq.active, sq.exists])
	for b in w.bullets:
		out.append([b.x, b.y, b.alive])
	out.append(w.render())
	return out


## A scripted session through Enhanced press()/tick() must leave the same
## Direct-owned state (and render list) as the same events on a bare Logic twin.
func _test_parity_vs_direct() -> void:
	var inst = (load(SCENE) as PackedScene).instantiate()
	root.add_child(inst)
	_check(inst.world.get_script() == Logic, "uses the Direct gsl_demo_logic.gd (no rules copy)")
	inst.world = Logic.new()
	inst._snap_prev()
	var d = Logic.new()
	inst.playing = true
	inst._show_card("")
	# [events, steps]: events apply before the first step of the segment.
	var script := [
		[[], 3],
		[[["press", 150, 150], ["release", 150, 150]], 1],  # menu → play (no shot)
		[[], 2],
		[[["press", 55, 10]], 1],                            # col 0: kill bottom square
		[[["drag", 60, 12], ["release", 60, 12]], 40],
		[[["press", 130, 0]], 1],                            # col 1 bottom square
		[[["press", 205, 0]], 1],                            # col 2 bottom square
		[[["press", 280, 0]], 1],                            # empty lane → miss off the top
		[[["press", 10, 0]], 1],                             # rack empty → dry click
		[[], 90],
		[[["press", 55, 0]], 1],                             # dead col 0 square soaks
		[[["press", 57, 0]], 1],
		[[], 30],
		[[["press", 0, 0], ["press", 100, 0], ["press", 290, 0]], 120],
	]
	var same := true
	var n := 0
	for seg in script:
		var evs: Array = seg[0]
		for e in evs:
			match String(e[0]):
				"press":
					d.mouse_pressed(int(e[1]), int(e[2]))
				"release":
					d.mouse_released(int(e[1]), int(e[2]))
				"drag":
					d.mouse_dragged(int(e[1]), int(e[2]))
		for i in int(seg[1]):
			inst.tick(evs if i == 0 else [])
			d.step()
			same = same and _snapshot(d) == _snapshot(inst.world)
			n += 1
	_check(same, "state/bg/squares/bullets/render list match Direct over %d scripted ticks" % n)
	_check(inst.world.state == Logic.State.PLAY, "script ends in play")
	var dead := 0
	for sq in inst.world.squares:
		if not sq.alive:
			dead += 1
	_check(dead == 3 and not inst.world.squares[2].alive and inst.world.squares[1].alive and inst.world.squares[0].alive,
		"bottom row down, upper rows protected by soaking dead squares (%d down)" % dead)
	_check(inst._starts == 1, "observer: one menu → play start")
	_check(inst._hits == 3, "observer: 3 hits counted (%d)" % inst._hits)
	_check(inst._soaks >= 2, "observer: dead-square soaks counted (%d)" % inst._soaks)
	_check(inst._fizzles >= 1, "observer: off-the-top misses counted (%d)" % inst._fizzles)
	_check(inst._dry_clicks >= 1, "observer: dry click with an empty rack counted (%d)" % inst._dry_clicks)
	_check(inst._shots == inst._hits + inst._soaks + inst._fizzles + (3 - inst._ready_bullets()),
		"observer: every shot accounted for (hit / soak / miss / in flight)")

	# Clear the board on both twins → Direct switches back to the menu.
	for w in [d, inst.world]:
		for sq in w.squares:
			sq.alive = false
	inst._snap_prev()
	inst.tick([])
	d.step()
	_check(_snapshot(d) == _snapshot(inst.world) and inst.world.state == Logic.State.MENU,
		"cleared board returns to the Direct menu on both")
	_check(inst._clears == 1, "observer: board clear counted")
	inst.free()


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("gamesketchlib_demo", "enhanced")
	_check(entry != null and entry.is_playable() and entry.scale_mode == "letterbox",
		"registry: enhanced playable, letterbox")
	_check(reg.get_entry("gamesketchlib_demo", "direct").is_playable(), "registry: direct still playable")
	_check(entry.scene_path == SCENE, "registry points at enhanced/game.tscn")

	reg.launch(entry)
	await _frames(6)
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.world.get_script() == Logic, "launched world is Direct gsl_demo_logic.gd")
	_check(not inst.playing and inst._cards["title"].visible, "boots on the title card")
	_check(inst.world.state == Logic.State.MENU, "Direct sim held on its menu under the title")

	var back: Button = null
	var start: Button = null
	for b in inst._ui.find_children("*", "Button", true, false):
		if b.text == "Back to Arcade":
			back = b
		elif b.text == "Start":
			start = b
	_check(back != null and back.focus_mode == Control.FOCUS_NONE, "Back to Arcade present, FOCUS_NONE")
	_check(start != null and start.focus_mode == Control.FOCUS_NONE, "title has a Start button (FOCUS_NONE)")

	var field: Control = inst._field
	_check(field != null and field.clip_contents, "field exists and clips")
	_check(is_equal_approx(field.size.x, Logic.W * inst.PX) \
		and is_equal_approx(field.size.y, Logic.H * inst.PX), "field is 300×300 @2× (600×600)")
	_check(Rect2(Vector2.ZERO, inst.STAGE).encloses(Rect2(field.position, field.size)),
		"field fits inside the 1280×720 stage")

	# Field clicks are ignored on the title card.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(300, 300)
	inst._on_field_input(click)
	_check(inst.world.state == Logic.State.MENU and inst._steps == 0, "title ignores field clicks; sim idle")

	# Start button leaves the title.
	start.pressed.emit()
	await _frames(3)
	_check(inst.playing and not inst._cards["title"].visible, "Start leaves the title for play")
	_check(inst._steps > 0, "sim steps once playing")

	# A field click (in 2× field pixels) reaches Direct as sketch coords: menu → play.
	inst._on_field_input(click)
	var up := click.duplicate()
	up.pressed = false
	inst._on_field_input(up)
	_check(inst.world.state == Logic.State.PLAY, "field click starts Direct play")
	await _frames(2)

	# Fire juice: click at field x=110 → sketch x=55 (column 0).
	var fire := click.duplicate()
	fire.position = Vector2(110, 300)
	var p0: int = inst._particles.size()
	var shots0: int = inst._shots
	inst._on_field_input(fire)
	_check(inst._shots == shots0 + 1 and inst.world.bullets[0].alive \
		and is_equal_approx(inst.world.bullets[0].x, 55.0), "click fires a Direct bullet at sketch x=55")
	_check(inst._particles.size() > p0 and inst._rings.size() > 0, "fire: muzzle burst + ring juice")
	inst.tick([])
	inst.tick([])
	_check(inst._trails[0].size() >= 2, "bullet trail builds while in flight")

	# Hit juice (drive with tick so the frame clock can't interfere).
	inst.playing = false
	var hits0: int = inst._hits
	for i in 40:
		inst.tick([])
	_check(inst._hits == hits0 + 1 and not inst.world.squares[2].alive, "bullet kills the bottom square → hit counted")
	_check(inst._floaters.size() > 0 and (inst._shake > 0.0 or inst._flash > 0.0), "hit: floater + shake/flash juice")
	var soaks0: int = inst._soaks
	inst.tick([["press", 55, 0]])
	for i in 20:
		inst.tick([])
	_check(inst._soaks == soaks0 + 1 and inst.world.squares[1].alive, "next shot soaked by the dead square → soak counted")
	inst._refresh_hud()
	_check(inst._squares_label.text.begins_with("SQUARES  8 / 9"), "HUD shows live squares (%s)" % inst._squares_label.text)
	inst.playing = true

	# Esc → PauseOverlay (tree pause), Esc again → arcade
	var steps0: int = inst._steps
	root.push_input(_key(KEY_ESCAPE))
	await _frames(8)
	_check(paused and inst._steps == steps0, "Esc opens PauseOverlay and freezes the run")
	root.push_input(_key(KEY_ESCAPE))
	await _frames(4)
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")
