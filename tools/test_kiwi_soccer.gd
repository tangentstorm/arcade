extends SceneTree
## Headless checks for Kiwi Soccer Direct against numbers taken from the original
## (sabren/blaze pyweek/ health.py + statusbox.py run under Python 3, and the pyODE run).
## Run: godot --headless --path . --script res://tools/test_kiwi_soccer.gd

const L := preload("res://games/kiwi_soccer/direct/kiwi_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: kiwi_soccer ", msg)
		_fail += 1


func _initialize() -> void:
	_logic()
	_scene.call_deferred()


func _logic() -> void:
	var h := L.new()
	_check(h.blood == 1000 and h.fat == 5000 and h.blood_black == 1 and h.fat_black == 1, "start: blood 1000, fat 5000, bars 1px")
	_check(absf(h.mass() - 8578.6) < 0.1, "Bird mass = sphere r16 at density 0.0001*fat (8578.6)")
	# Same script fed to the original HealthModel/StatusBox: exert(3) twice at step 5, once at
	# 9/19/29/39/49, exert(5) twice at 70; every step is step() then eat(Food(5,5)).
	var want := {0: [1003, 5006, 281, 281], 1: [976, 5027, 284, 281], 10: [823, 5081, 298, 280],
		49: [700, 5315, 310, 276], 149: [800, 5915, 300, 264]}
	var ok := true
	for i in 150:
		if i == 5:
			h.exert(3)
			h.exert(3)
		if i % 10 == 9 and i < 50:
			h.exert(3)
		if i == 70:
			h.exert(5)
			h.exert(5)
		h.step()
		h.eat(5, 5)
		if want.has(i):
			var got := [h.blood, h.fat, h.blood_black, h.fat_black]
			if got != want[i]:
				ok = false
				print("  step ", i, " got ", got, " want ", want[i])
	_check(ok, "metabolism + bar heights match the original at steps 0/1/10/49/149")
	var s := L.new()
	for i in 60:
		s.exert(3)
	_check(s.blood == 0 and s.fat == 2400, "exertion past blood sugar burns fat (60 runs -> 0 / 2400)")
	s.step()
	_check(s.blood == 3 and s.fat == 2396, "low blood recovers 5 from fat, then insulin 2 (3 / 2396)")
	_check(L.run_force(L.RIGHT) == Vector2(1e8, 0) and L.run_force(L.LEFT) == Vector2(-1e8, 0),
		"run = force 20*5e6")
	_check(L.jump_force() == Vector2(0, -4e7), "jump = force -8*5e6")
	var c := L.Controller.new()
	c.key_down("RIGHT")
	var reposts := 0
	for i in 30:
		reposts += c.tick().size()
	c.key_up("RIGHT")
	for i in 10:
		reposts += c.tick().size()
	_check(reposts == 3, "Controller re-posts held buttons every 10 ticks")
	var tab := [["AAA", 2000], ["BBB", 1000]]
	_check(L.place_for([], 1000) == 0 and L.place_for(tab, 1500) == 1, "score placement")
	_check(L.place_for(tab, 3000) == 1, "score placement keeps the original's off-by-one for a new best")
	_check(L.place_for(tab, 500) == 2, "score below every entry appends (original raises IndexError)")


func _key(g: Node, code: int, pressed := true) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = pressed
	g._gui_input(e)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _scene() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://kiwi_soccer_scores.json"))
	var g = load("res://games/kiwi_soccer/direct/game.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.set_process(false)  # tick by hand below, one Game.tick per call
	_check(g.state == g.St.MENU, "opens on the menu")
	_key(g, KEY_P)
	_check(g.state == g.St.LEVELS and g.selected == 0, "P -> level list")
	_key(g, KEY_DOWN)
	_key(g, KEY_DOWN)
	_check(g.selected == 1, "Down clamps at the last room")
	_key(g, KEY_ENTER)
	_check(g.state == g.St.LEVELS, "joe1 (missing files in the original) does not start")
	_key(g, KEY_UP)
	_key(g, KEY_ENTER)
	_check(g.state == g.St.GAME and g.world != null, "outside starts the game")
	# Same inputs as the pyODE reference run of the original (keys posted before Game.tick k).
	var script := {80: [[KEY_RIGHT, true]], 110: [[KEY_RIGHT, false]], 130: [[KEY_SPACE, true]],
		131: [[KEY_SPACE, false]], 150: [[KEY_LEFT, true]], 260: [[KEY_LEFT, false]]}
	# tick: [hero x, hero y, blood, fat] from the original after Game.tick k.
	var ref := {40: [150.0, 411.784, 1000, 5300], 70: [150.0, 470.319, 1000, 5525],
		90: [190.866, 439.262, 790, 5660], 100: [216.705, 428.709, 760, 5720],
		140: [250.418, 400.43, 580, 5960], 200: [122.639, 371.343, 280, 6320],
		260: [1.705, 468.275, 160, 6680]}
	var worst := Vector2.ZERO
	var meta_ok := true
	var b0 := 0
	var ball_seen := false
	for k in range(1, 261):
		for e in script.get(k, []):
			_key(g, e[0], e[1])
		g.tick()
		if k == 1:
			var br: Rect2 = g.ball_rect()
			_check(br.size == Vector2(32, 32) and br.position.round() == Vector2(34, 34),
				"soccer.png ball drawn 32x32 at the default Ball spot (50, 50)")
		ball_seen = ball_seen or g.ball_rect().position.y > 440  # lands on the floor in view
		if k == 79:
			b0 = g.health.blood
		if k == 81:
			_check(g.world.hero.vel.x > 190 and not g.facing_left, "a press runs twice (leaked LevelList controller): vx %.0f" % g.world.hero.vel.x)
		if k == 82:
			_check(g.health.blood < b0, "running burns blood sugar")
		if k == 151:
			_check(g.facing_left, "Left flips the sprite")
		if ref.has(k):
			var r: Array = ref[k]
			var w = g.world
			worst = worst.max(Vector2(absf(w.hero.pos.x - r[0]), absf(w.hero.pos.y - r[1])))
			meta_ok = meta_ok and g.health.blood == r[2] and g.health.fat == r[3]
	_check(meta_ok, "blood/fat match the original tick for tick under the same inputs")
	_check(worst.x < 2.0 and worst.y < 15.0,
		"kiwi tracks the pyODE run (max err x %.2f, y %.2f px)" % [worst.x, worst.y])
	_check(ball_seen, "the ball drops onto the floor where it can be seen")
	# Kick: ball at rest on the floor at x=50, kiwi runs left into it (pyODE: the ball leaves
	# at ~1.7x the kiwi's speed and runs off the end of the floor).
	g.world.hero.pos = Vector2(150, 464)
	g.world.hero.vel = Vector2.ZERO
	g.world.ball.pos = Vector2(50, 464)
	g.world.ball.vel = Vector2.ZERO
	g.world.ball.spin = 0.0
	for i in 30:
		g.tick()
	_check(absf(g.world.ball.pos.x - 50) < 0.5, "a resting ball stays put")
	_key(g, KEY_LEFT)
	var kicked := false
	for i in 40:
		g.tick()
		if g.world.ball.vel.x < -50:
			kicked = true
			break
	_key(g, KEY_LEFT, false)
	for i in 15:
		g.tick()
	var h = g.world.hero
	var b = g.world.ball
	_check(kicked and b.vel.x < h.vel.x and b.pos.x < h.pos.x - 40,
		"running into the ball kicks it ahead of the kiwi (ball x %.0f vx %.0f, kiwi x %.0f vx %.0f)" % [b.pos.x, b.vel.x, h.pos.x, h.vel.x])
	_check(b.vel.x < -50 and absf(b.spin * b.radius - b.vel.x) < 5.0,
		"the kicked ball rolls along the floor (vx %.0f, spin*r %.0f)" % [b.vel.x, b.spin * b.radius])
	g.world.hero.pos = Vector2(-20, 440)
	g.world.hero.vel = Vector2.ZERO
	for i in 100:
		g.tick()
	_check(g.world.hero.pos.y > 520, "no glass walls: past x<0 the kiwi falls off the floor")
	_key(g, KEY_X)
	await process_frame
	_check(g.state == g.St.MENU and g.world == null, "X quits to the menu")
	_key(g, KEY_E)
	_check(g.state == g.St.HELP, "E -> help")
	_key(g, KEY_Q)
	_key(g, KEY_C)
	_check(g.state == g.St.CREDITS, "any key back, C -> credits")
	_key(g, KEY_Q)
	_key(g, KEY_1)
	_check(g.state == g.St.SCORE_ENTRY, "hidden 1 -> initials entry")
	for k in [KEY_A, KEY_B, KEY_C, KEY_D, KEY_BACKSPACE, KEY_D, KEY_ENTER]:
		_key(g, k)
	_check(g.state == g.St.SCORES and g.scores == [["ABD", 1000]], "initials entry saves ABD 1000")
	_key(g, KEY_Q)
	_key(g, KEY_H)
	_check(g.state == g.St.SCORES, "H -> high scores")
	g.queue_free()
	await process_frame
	await create_timer(0.5).timeout  # let the audio server drop the stopped playbacks
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://kiwi_soccer_scores.json"))
	print("VERIFY DONE: ", _fail)
	quit(_fail)
