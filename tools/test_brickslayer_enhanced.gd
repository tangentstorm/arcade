extends SceneTree
## Headless checks for the Brickslayer Enhanced edition.
## Run: godot --headless --path . --script res://tools/test_brickslayer_enhanced.gd

const Logic := preload("res://games/brickslayer/enhanced/brickslayer_enhanced_logic.gd")
const Direct := preload("res://games/brickslayer/direct/brickslayer_logic.gd")
const SCENE := "res://games/brickslayer/enhanced/game.tscn"
const STORE := "user://test_brickslayer_enhanced_scores.cfg"

var _fail := 0
var _games: Array = []


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: brickslayer_enhanced ", msg)
	else:
		print("SMOKE FAIL: brickslayer_enhanced ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _mk() -> Logic:
	var g := Logic.new(STORE)
	_games.append(g)
	return g


func _ticks(g, n: int) -> void:
	for i in n:
		g.tick()


func _types(events: Array) -> Array:
	return events.map(func(e): return e.type)


func _run() -> void:
	await _test_scene()
	_test_same_as_direct()
	_test_events()
	_test_lives_and_game_over()
	_test_level_clear()
	_test_steering()
	for g in _games:
		g.dispose()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	quit(1 if _fail else 0)


func _test_scene() -> void:
	_check(load(SCENE) is PackedScene, "scene loads")
	var reg = root.get_node("GameRegistry")
	var entry = reg.get_entry("brickslayer", "enhanced")
	_check(entry.is_playable() and entry.scale_mode == "letterbox", "registry: enhanced playable, letterbox")
	_check(reg.get_entry("brickslayer", "direct").is_playable(), "registry: direct still playable")
	reg.launch(entry)
	for i in 5:
		await process_frame
	var inst = current_scene
	_check(inst != null and inst.scene_file_path == SCENE, "launch opens the enhanced scene")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox keeps aspect")
	_check(inst.logic.screen == "title" and inst._cards["title"].visible, "boots on the title card")
	root.push_input(_key(KEY_SPACE))
	await process_frame
	_check(inst.logic.screen == "game" and inst.logic.ball.on_paddle, "space on title -> game, ball on paddle")
	_check(not inst._cards["title"].visible and inst._serve_hint.visible, "title card hides, serve hint shows")
	root.push_input(_key(KEY_SPACE, false))
	root.push_input(_key(KEY_SPACE))
	await process_frame
	_check(not inst.logic.ball.on_paddle and inst.logic.ball.dy == Direct.SERVE_SPEED, "space serves at Direct speed -4")
	root.push_input(_key(KEY_RIGHT))
	for i in 5:
		await process_frame
	_check(inst.logic.paddle.velocity == 5, "right arrow drives the paddle at Direct speed 5")
	root.push_input(_key(KEY_RIGHT, false))
	await process_frame
	_check(inst.logic.paddle.velocity == 0, "release stops the paddle")
	# drive the view's juice path directly
	var b = inst.logic.bricks[4]
	inst.logic._brick_hit(b)
	inst.step_tick()
	_check(inst._brick_flash.has(4) and inst._particles.size() > 0 and inst._floaters.size() > 0,
		"brick hit -> flash, sparks and +1")
	root.push_input(_key(KEY_P))
	await process_frame
	_check(inst.logic.screen == "pause" and inst._cards["pause"].visible, "P shows the pause card")
	root.push_input(_key(KEY_P))
	await process_frame
	_check(inst.logic.screen == "game", "P again resumes")
	root.push_input(_key(KEY_ESCAPE))
	await process_frame
	var t0: int = inst.logic.clock_ms
	for i in 10:
		await process_frame
	_check(paused and inst.logic.clock_ms == t0, "Esc opens the PauseOverlay and freezes the game")
	root.push_input(_key(KEY_ESCAPE))
	for i in 3:
		await process_frame
	_check(reg.in_arcade() and not paused, "Esc again -> Back to Arcade")


## With no pointer, the Enhanced rules must play out tick-for-tick like Direct.
func _test_same_as_direct() -> void:
	var d = Direct.new(Direct.LAST_STEP, STORE)
	_games.append(d)
	var e := _mk()
	d.key_up(KEY_ENTER)
	e.start()
	var same := true
	for t in 6000:
		if t % 900 == 0 and d.ball.on_paddle:
			d.key_down(KEY_UP)
			e.try_serve()
		if t % 400 == 50:
			d.key_down(KEY_LEFT); e.set_held(true, false)
		if t % 400 == 120:
			d.key_up(KEY_LEFT); e.set_held(false, false)
		if t % 400 == 250:
			d.key_down(KEY_RIGHT); e.set_held(false, true)
		if t % 400 == 330:
			d.key_up(KEY_RIGHT); e.set_held(false, false)
		d.tick()
		e.tick()
		if d.ball.x != e.ball.x or d.ball.y != e.ball.y or d.paddle.x != e.paddle.x \
				or d.score != e.score or d.balls_left != e.balls_left or d.brick_count != e.brick_count:
			same = false
			print("  diverged at tick %d" % t)
			break
		if d.screen != "game":
			break
	_check(same and e.score > 0, "60 s of play matches Direct tick-for-tick (score %d, bricks %d)" % [e.score, e.brick_count])
	_check(e.bricks.size() == 50 and e.bricks[4].start_shade == 5 and e.bricks[0].start_shade == 1,
		"same 10x5 wall and shades")


func _test_events() -> void:
	var g := _mk()
	g.start()
	g.take_events()
	g.try_serve()
	_check(_types(g.take_events()) == [&"serve"], "serve event")
	g._brick_hit(g.bricks[4])
	var ev := g.take_events()
	_check(ev.size() == 1 and ev[0].type == &"brick_hit" and ev[0].index == 4 and ev[0].shade == 5,
		"hit event names the brick and its shade")
	g._brick_hit(g.bricks[0])
	ev = g.take_events()
	_check(ev[0].type == &"brick_break" and g.brick_count == 49, "shade-1 brick breaks")
	g.ball.set_x(2); g.ball.set_y(200); g.ball.dx = -3; g.ball.dy = -1
	g.tick()
	_check(g.ball.dx == 3 and _types(g.take_events()).has(&"wall"), "wall bounce event")
	g.ball.set_x(g.paddle.x + 20); g.ball.set_y(g.paddle.y - 18); g.ball.dx = 1; g.ball.dy = 4
	g.tick()
	_check(g.ball.dy == -4 and _types(g.take_events()).has(&"paddle"), "paddle bounce event")


func _test_lives_and_game_over() -> void:
	var g := _mk()
	g.start()
	g.score_set(7)
	for i in 3:
		g.lose_life()
	_check(g.balls_left == 0 and g.screen == "game", "three spares, as in Direct")
	g.take_events()
	g.lose_life()
	var ev := g.take_events()
	_check(g.screen == "gameover" and ev[0].type == &"lost" and ev[0].last, "fourth loss -> game over")
	_check(g.best == 7 and g.new_best and g.player_score == 7, "best score recorded")
	_ticks(g, 1000)
	_check(g.screen == "gameover" and g.score == 7, "game over waits for the player (no timed hop)")
	g._over_at_ms = g.clock_ms
	_check(not g.start() and g.screen == "gameover", "restart ignored during the lockout")
	_ticks(g, Logic.RESTART_LOCK_MS / Logic.TICK_MS)
	_check(g.start() and g.screen == "game", "restart after the lockout")
	_check(g.score == 0 and g.balls_left == 3 and g.brick_count == 50 and g.current_level == 1,
		"restart resets score, lives, wall and level")
	_check(not g.new_best and g.best == 7, "best kept across runs")


func _test_level_clear() -> void:
	var g := _mk()
	g.start()
	for b in g.bricks:
		while b.solid:
			g._brick_hit(b)
	_check(g.screen == "clear" and g.score == 0, "level clear screen")
	_ticks(g, 200)
	_check(g.screen == "game" and g.current_level == 2 and g.brick_count == 50 and g.ball.on_paddle,
		"next level after 2 s, as in Direct")


func _test_steering() -> void:
	var g := _mk()
	g.start()
	g.set_held(true, false)
	g.set_held(true, true)
	g.set_held(false, true)
	g.tick()
	_check(g.paddle.velocity == 5, "releasing left while right is held keeps moving right")
	g.set_held(false, false)
	g.pointer_x = 20.0
	g.tick()
	_check(g.paddle.velocity == -5, "pointer drives paddle at most 5 px/tick")
	_ticks(g, 100)
	_check(g.paddle.x == 0, "pointer target clamps at the wall")
	g.pointer_x = 32.0 + 3.0
	g.tick()
	_check(g.paddle.velocity == 3 and g.paddle.x == 3, "pointer eases into place")
	g.set_held(true, false)
	_check(is_nan(g.pointer_x), "a key press hands control back to the keys")
