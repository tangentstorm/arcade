extends SceneTree
## Headless logic checks for the invader_sketch direct port.
## Run: godot --headless --path . --script res://tools/test_invader_sketch.gd

const L := preload("res://games/invader_sketch/direct/invader_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: invader_sketch ", msg)
		_fail += 1


func _count(arr: Array, kind: String) -> int:
	var n := 0
	for o in arr:
		if o.kind == kind:
			n += 1
	return n


func _initialize() -> void:
	# Menu -> Space -> Play
	var m = L.new(L.MENU, 1)
	_check(m.state == L.MENU, "starts on menu")
	m.step({})
	_check(m.state == L.MENU, "menu waits for space")
	m.step({"just": ["space"]})
	_check(m.state == L.PLAY, "space starts play")

	# PlayState.create() layout
	var w = L.new(L.PLAY, 42)
	_check(w.invaders.size() == 28, "28 invaders (%d)" % w.invaders.size())
	_check(_count(w.invaders, "ship") == 7 and w.ship_invaders.size() == 7, "row 0: 7 ShipInvaders")
	_check(_count(w.invaders, "spin") == 14, "rows 1 and 3: 14 SpinInvaders")
	_check(_count(w.invaders, "jell") == 7, "row 2: 7 JellInvaders")
	_check(w.shields.size() == 9, "9 shields")
	_check(w.hero.x == 295 and w.hero.y == 430, "hero at (295,430)")
	_check(w.bullets_left == 3, "3 bullets of ammo")
	_check(w.invaders[0].x == 65 and w.invaders[0].y == 25, "first ship at (65,25)")

	# Movement: 3.5 px per frame, clamped to the screen
	w.step({"left": true})
	_check(is_equal_approx(w.hero.x, 291.5), "left moves 3.5px (%s)" % w.hero.x)
	for i in 200:
		w.step({"left": true})
	_check(w.hero.x == 0, "hero clamps at left edge")

	# Spin invaders stay within about ±63 degrees and change angle
	var spin = null
	for o in w.invaders:
		if o.kind == "spin":
			spin = o
			break
	var d0: int = spin.degrees
	w.step({})
	_check(spin.degrees != d0 and absi(spin.degrees) <= 63, "spin invader rotates (%d -> %d)" % [d0, spin.degrees])

	# Fleet shift: 2px every shift-timer tick (7 frames at 60 fps, > 100 ms)
	var f = L.new(L.PLAY, 7)
	var ship = f.ship_invaders[0]
	for i in 6:
		f.step({})
	_check(ship.x == 65, "fleet holds for 6 frames")
	f.step({})
	_check(ship.x == 67, "fleet shifts 2px on frame 7 (%s)" % ship.x)

	# Shooting: hero bullet travels up, kills an invader above
	var s = L.new(L.PLAY, 3)
	s.hero.x = 200  # in the gap between shield groups, under column 3
	s.step({})
	s.step({"just": ["space"]})
	_check(s.bullets_left == 2, "shoot uses one bullet (%d)" % s.bullets_left)
	var before: int = s.invaders.size()
	var n := 0
	while s.invaders.size() == before and n < 400:
		s.step({}); n += 1
	_check(s.invaders.size() == before - 1, "bullet kills an invader (frame %d)" % n)
	for i in 5:
		s.step({})
	_check(s.bullets_left == 3, "dead bullet returns to the ammo rack")

	# Shields take 3 hits; frame advances 12 -> 13 -> 14
	var sh = L.new(L.PLAY, 4)
	var shield = sh.shields[0]
	_check(shield.sheet_cell() == 12, "shield starts on frame 12")
	shield.hurt()
	_check(shield.sheet_cell() == 13 and shield.alive, "shield hit 1 -> frame 13")
	shield.hurt()
	_check(shield.sheet_cell() == 14 and shield.alive, "shield hit 2 -> frame 14")
	shield.hurt()
	_check(not shield.alive and not shield.visible, "shield hit 3 -> destroyed")
	sh.step({})
	_check(sh.shields.size() == 8, "dead shield removed")

	# Enemy fire: ships shoot after the first (skipped) tick; a bullet on the hero ends the game
	var e = L.new(L.PLAY, 5)
	n = 0
	while e.enemy_bullets.is_empty() and n < 60 * 10:
		e.step({}); n += 1
	_check(not e.enemy_bullets.is_empty(), "ship invaders fire (frame %d)" % n)
	var eb = e.enemy_bullets[0]
	eb.x = e.hero.x
	eb.y = e.hero.y - 10
	e.step({})
	e.step({})
	_check(e.state == L.GAMEOVER, "enemy bullet on hero -> game over")
	e.step({"just": ["space"]})
	_check(e.state == L.MENU, "space on game over -> menu")

	# Win: all invaders dead
	var v = L.new(L.PLAY, 6)
	for o in v.invaders:
		o.hurt()
	v.step({})
	_check(v.state == L.WIN, "all invaders dead -> win")
	v.step({"just": ["space"]})
	_check(v.state == L.MENU, "space on win -> menu")

	# Invasion: fleet reaching y >= 380 -> game over (no shooting)
	var g = L.new(L.PLAY, 8)
	n = 0
	while g.state == L.PLAY and n < 60 * 600:
		# keep the hero out of enemy fire's way by deleting enemy bullets
		g.enemy_bullets.clear()
		g.step({}); n += 1
	_check(g.state == L.GAMEOVER, "fleet descends -> game over (frame %d)" % n)

	print("invader_sketch tests: %s" % ("PASS" if _fail == 0 else "%d FAIL" % _fail))
	quit(1 if _fail else 0)
