extends SceneTree
## Headless logic checks for the flappy_clone direct port.
## Run: godot --headless --path . --script res://tools/test_flappy_clone.gd

const Logic := preload("res://games/flappy_clone/direct/flappy_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: flappy_clone ", msg)
	else:
		print("SMOKE FAIL: flappy_clone ", msg)
		_fail += 1


func _run_frames(g, seconds: float, autopilot: bool) -> void:
	var t := 0.0
	while t < seconds and g.state == Logic.State.PLAY:
		if autopilot and g.bird_pos.y < -0.35 and g.bird_vy < -3.5:
			g.jump()
		g.update(1.0 / 60.0)
		t += 1.0 / 60.0


func _initialize() -> void:
	var g = Logic.new()
	_check(g.state == Logic.State.TITLE and not g.bird_visible, "starts on title, bird hidden")
	g.update(1.0)
	_check(is_equal_approx(g.scroll, Logic.SCROLL_SPEED), "world scrolls on the title screen")
	g.jump()
	_check(g.state == Logic.State.TITLE, "jump does nothing on title")
	g.play_game()
	_check(g.state == Logic.State.INTRO and g.bird_visible, "Play -> intro, bird shown")
	g.update(2.0)
	_check(g.bird_pos == Logic.BIRD_START, "bird held during intro")
	g.scroll = 0.0  # next gate at x=4: about 0.9 s of open sky ahead
	g.jump()
	_check(g.state == Logic.State.PLAY and is_equal_approx(g.bird_vy, Logic.FIRST_FLAP),
		"first jump -> play with the 2.5 first flap")
	g.jump()
	_check(is_equal_approx(g.bird_vy, Logic.FIRST_FLAP + Logic.PRESS_FLAP), "press flap adds 7.5")
	# hold the bird against the ceiling for a while: harmless
	for i in 30:
		g.jump()
		g.update(1.0 / 60.0)
	_check(g.state == Logic.State.PLAY, "ceiling is harmless")
	_check(g.bird_pos.y <= Logic.CEIL_BOTTOM - Logic.BIRD_RADIUS + 1e-6, "ceiling clamps the bird")
	# no input: fall to the floor (or into a pipe) and die
	_run_frames(g, 5.0, false)
	_check(g.state == Logic.State.GAME_OVER and not g.bird_visible, "falling ends the run, bird hidden")
	g.jump()
	_check(g.state == Logic.State.GAME_OVER, "jump does nothing on game over")

	# a careful autopilot can thread the fixed y=0 gaps and score 10 per gate
	g = Logic.new()
	g.play_game()
	g.jump()
	_run_frames(g, 12.0, true)
	_check(g.state == Logic.State.PLAY, "autopilot survives 12 s")
	_check(g.score >= 30 and g.score % 10 == 0, "autopilot scores per gate: %d" % g.score)
	g.play_game()
	_check(g.state == Logic.State.PLAY, "Play ignored mid-run")
	_run_frames(g, 5.0, false)
	g.play_game()
	_check(g.state == Logic.State.INTRO and g.bird_pos == Logic.BIRD_START, "retry -> intro, bird reset")
	g.jump()
	_check(g.score == 0, "score resets when the run starts")
	quit(1 if _fail else 0)
