extends SceneTree
## Headless logic checks for the GameSketchLib course w02 demo ports:
## overlap_demo, overlap_demo_live, bullet_demo, bullet_demo_live, gamesketchlib_demo,
## keyboard_test_workaround, keyboard_test_buggy, keyboard_test_hashmap.
## Run: godot --headless --path . --script res://tools/test_gsl_demos.gd

const Overlap := preload("res://games/overlap_demo/direct/overlap_logic.gd")
const OverlapLive := preload("res://games/overlap_demo_live/direct/overlap_live_logic.gd")
const Bullet := preload("res://games/bullet_demo/direct/bullet_logic.gd")
const BulletLive := preload("res://games/bullet_demo_live/direct/bullet_live_logic.gd")
const GslDemo := preload("res://games/gamesketchlib_demo/direct/gsl_demo_logic.gd")
const KbWork := preload("res://games/keyboard_test_workaround/direct/kb_workaround_logic.gd")
const KbBuggy := preload("res://games/keyboard_test_buggy/direct/kb_buggy_logic.gd")
const KbHash := preload("res://games/keyboard_test_hashmap/direct/kb_hashmap_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: gsl_demos ", msg)
		_fail += 1


func _rects(frame: Array) -> Array:
	return frame.filter(func(c): return c[0] == "rect")


func _test_overlap(L, tag: String) -> void:
	var w = L.new()
	_check(w.squares.size() == 9, tag + " 9 squares")
	_check(w.squares[1].x == 50 and w.squares[1].y == 125, tag + " index i*3+j: [1] at (50,125)")
	w.step()
	_check(w.squares.all(func(s): return s.fill_color == L.WHITE), tag + " all white at start")
	var fr: Array = w.render()
	_check(fr[0][1] == Color("#3366FF") and _rects(fr).size() == 9, tag + " blue bg + 9 rects")
	# grab the centre square (125,125) by its middle and drag it onto (200,125)
	w.mouse_pressed(137, 137)
	_check(w.in_hand == w.squares[4], tag + " press picks centre square")
	w.mouse_dragged(200, 140)
	_check(w.squares[4].x == 188 and w.squares[4].y == 128, tag + " drag keeps grab offset (%s,%s)" % [w.squares[4].x, w.squares[4].y])
	w.step()
	_check(w.squares[4].fill_color == L.GRAY and w.squares[7].fill_color == L.GRAY, tag + " overlapping pair turns gray")
	_check(w.squares[0].fill_color == L.WHITE, tag + " others stay white")
	w.mouse_released(200, 140)
	w.mouse_dragged(10, 10)
	_check(w.squares[4].x == 188, tag + " release drops the square")
	# edge-touching is not an overlap (strict <)
	w.squares[4].x = 175  # x2 = 200 == squares[7].x
	w.squares[4].y = 125
	w.step()
	_check(w.squares[4].fill_color == L.WHITE, tag + " touching edges don't overlap")
	# pressing a stack picks the lowest index
	w.squares[8].x = 50
	w.squares[8].y = 50
	w.mouse_pressed(55, 55)
	_check(w.in_hand == w.squares[0], tag + " stacked press grabs lowest index")


func _test_bullet() -> void:
	var w = Bullet.new()
	w.step()
	_check(w.bullets_left == 3, "bullet: 3 in rack")
	_check(w.bullets[0].x == 0 and w.bullets[1].x == 10 and w.bullets[2].y == 280, "bullet: rack at (10i, 280)")
	w.mouse_pressed(55, 200)
	_check(w.bullets_left == 2 and w.bullets[0].alive and w.bullets[0].x == 55 and w.bullets[0].y == 260, "bullet: fires from (mouseX, 260)")
	for i in 3:
		w.mouse_pressed(150, 10)
	_check(w.bullets_left == 0, "bullet: can't fire more than 3 between frames")
	w.step()
	_check(w.bullets[0].y == 260 - 3.75, "bullet: moves 3.75 px/frame")
	var frames := 0
	while w.bullets[0].alive and frames < 200:
		w.step()
		frames += 1
	_check(not w.squares[2].alive, "bullet: hits bottom-left square (50,200)")
	_check(w.squares[1].alive, "bullet: stops at first hit")
	_check(w.squares[2].alive == false and w.render()[3][2] == Bullet.DEAD, "bullet: dead square drawn #CCCCCC")
	# shoot past the right edge of every column: flies off-screen and returns to the rack
	var w2 = Bullet.new()
	w2.step()
	w2.mouse_pressed(5, 200)
	for i in 120:
		w2.step()
	_check(not w2.bullets[0].alive and w2.bullets_left == 3, "bullet: off-screen bullet returns to the rack")


func _test_gsl_demo() -> void:
	var w = GslDemo.new()
	_check(w.state == GslDemo.State.MENU, "gsl: starts on the menu")
	var fr: Array = w.render()
	_check(fr[0][1] == Color.BLACK and fr[1][0] == "text" and fr[1][1] == "BulletDemo! Click to start.", "gsl: black menu with prompt")
	w.mouse_pressed(150, 150)
	_check(w.state == GslDemo.State.PLAY and w.squares.size() == 9 and w.bullets.size() == 3, "gsl: click starts play")
	_check(w.render()[0][1] == Color("#3366FF"), "gsl: play bg blue")
	w.step()
	w.mouse_pressed(55, 0)
	_check(w.bullets[0].alive and w.bullets[0].y == 260, "gsl: firstDead bullet fires")
	for i in 30:
		w.step()
	_check(not w.squares[2].alive and not w.bullets[0].alive, "gsl: bullet kills bottom square")
	# dead squares stay active, so they still absorb bullets
	w.mouse_pressed(55, 0)
	for i in 15:
		w.step()
	_check(not w.bullets[0].alive and w.squares[1].alive, "gsl: dead square soaks up the next bullet")
	# clear the board → back to the menu
	for sq in w.squares:
		sq.alive = false
	w.step()
	_check(w.state == GslDemo.State.MENU, "gsl: clearing every square returns to the menu")


func _test_bullet_live() -> void:
	var w = BulletLive.new()
	_check(w.state == BulletLive.State.MENU, "live: starts on the menu")
	w.mouse_pressed(1, 1)
	_check(w.state == BulletLive.State.PLAY, "live: click starts")
	_check(w.bullets[2].x == 20 and w.bullets[2].y == 280 and not w.bullets[2].active, "live: bullets start racked + inactive")
	w.step()
	w.mouse_pressed(55, 0)
	_check(w.bullets[0].active and w.bullets[0].y == 260, "live: firstInactive fires")
	for i in 30:
		w.step()
	_check(not w.squares[2].alive and not w.squares[2].active, "live: hit square is dead + inactive")
	w.mouse_pressed(55, 0)
	var killed_next := false
	for i in 80:
		w.step()
		if not w.squares[1].alive:
			killed_next = true
			break
	_check(killed_next, "live: bullets fly through dead squares and hit the next one")
	var fr: Array = w.render()
	_check(fr[1][2] == BulletLive.BULLET and fr[4 + 2][2] == BulletLive.DEAD, "live: bullets drawn first; dead squares #999999")
	for sq in w.squares:
		sq.alive = false
	w.step()
	_check(w.state == BulletLive.State.MENU, "live: clearing every square returns to the menu")


func _lit(frame: Array) -> Array:
	var out := []
	for c in _rects(frame):
		out.append(c[2] == Color8(255, 255, 255))
	return out


func _test_keyboards() -> void:
	var w = KbWork.new()
	_check(_lit(w.render()) == [false, false, false, false, false, false, false, false], "kb work: all dark")
	w.key_pressed("w", 87)
	w.key_pressed("CODED", 39)
	_check(_lit(w.render()) == [true, false, false, false, false, false, false, true], "kb work: w + right lit")
	w.key_pressed("w", 87)  # OS key-repeat toggles it back off
	_check(not _lit(w.render())[0], "kb work: key-repeat XOR flicker kept")
	w.key_pressed(",", 44)
	_check(_lit(w.render())[0], "kb work: dvorak ',' is north")
	w.key_released("CODED", 39)
	_check(not _lit(w.render())[7], "kb work: release clears right")

	var b = KbBuggy.new()
	b.key_pressed("d", 68)
	b.key_pressed("CODED", 38)
	var lb: Array = _lit(b.render())
	_check(lb[3] and not lb[4], "kb buggy: d lights, arrows stay dark (pjs CODED bug)")
	_check(b.probe == "PROBE", "kb buggy: arrow branch never runs")

	var h = KbHash.new()
	h.rng.seed = 1
	h.key_pressed("w", 87)
	h.step()
	var lh: Array = _lit(h.render())
	_check(not lh[0] and not lh[4], "kb hashmap: lowercase w is not in WASD_N")
	h.key_pressed("W", 87)
	h.key_pressed("CODED", 37)
	h.step()
	lh = _lit(h.render())
	_check(lh[0] and lh[4] and lh[5] and lh[9], "kb hashmap: W lights left+middle; LEFT lights middle+right")
	h.key_pressed("CODED", 37)  # repeat: not a new justPressed
	_check(h.just_pressed(37) == false, "kb hashmap: repeat isn't justPressed")
	var c0: Color = h.bg_color
	h.key_pressed(" ", 32)
	h.step()
	_check(h.render()[0][1] == c0 and h.bg_color != c0, "kb hashmap: Space recolours from the next frame")
	h.step()
	_check(h.just_pressed_keys.is_empty(), "kb hashmap: justPressed cleared each frame")
	h.key_released("CODED", 37)
	h.step()
	_check(not _lit(h.render())[11], "kb hashmap: release clears LEFT")


func _mouse_button(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	return ev


## Scene-level check: game.gd maps window clicks into 300×300 sketch coordinates.
func _test_scene_input() -> void:
	var game: Control = load("res://games/overlap_demo/direct/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var room: Control = game.get_node("%Room")
	var fit := minf(game.size.x, game.size.y) / 300.0
	_check(is_equal_approx(room.scale.x, fit) and room.position == ((game.size - Vector2(300, 300) * fit) * 0.5).round(),
		"scene: 300² stage scaled to fit %s and centred (%s, %s)" % [game.size, room.scale, room.position])
	var to_screen := func(p: Vector2) -> Vector2: return room.get_global_transform_with_canvas() * p
	root.push_input(_mouse_button(to_screen.call(Vector2(137, 137)), true), true)
	_check(game.world.in_hand == game.world.squares[4], "scene: click at sketch (137,137) grabs the centre square")
	var mv := InputEventMouseMotion.new()
	mv.position = to_screen.call(Vector2(200, 140))
	mv.global_position = mv.position
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mv, true)
	_check(absf(game.world.squares[4].x - 188) <= 1.0, "scene: drag moves it in sketch px (%s)" % game.world.squares[4].x)
	root.push_input(_mouse_button(to_screen.call(Vector2(200, 140)), false), true)
	_check(game.world.in_hand == null, "scene: release drops it")
	root.push_input(_mouse_button(to_screen.call(Vector2(-5, 150)), true), true)
	_check(game._buttons == 0, "scene: press outside the 300² canvas never reaches the sketch")
	root.push_input(_mouse_button(to_screen.call(Vector2(-5, 150)), false), true)
	game.queue_free()
	await process_frame

	var kb: Control = load("res://games/keyboard_test_workaround/direct/game.tscn").instantiate()
	root.add_child(kb)
	await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_UP
	key.pressed = true
	root.push_input(key, true)
	var kd := InputEventKey.new()
	kd.keycode = KEY_D
	kd.pressed = true
	root.push_input(kd, true)
	_check(kb.world.arrows == KbWork.N and kb.world.wasd == KbWork.E, "scene: Up → CODED UP, D → 'd'")
	kb.queue_free()
	await process_frame


func _initialize() -> void:
	_test_overlap(Overlap, "overlap")
	_test_overlap(OverlapLive, "overlap live")
	_test_bullet()
	_test_gsl_demo()
	_test_bullet_live()
	_test_keyboards()
	_finish.call_deferred()


func _finish() -> void:
	await _test_scene_input()
	if _fail == 0:
		print("test_gsl_demos: OK")
		quit(0)
	else:
		print("test_gsl_demos: FAILED (%d)" % _fail)
		quit(1)
