extends SceneTree
## Headless logic checks for the spiders_v_aliens direct port.
## Run: godot --headless --path . --script res://tools/test_spiders_v_aliens.gd

const L := preload("res://games/spiders_v_aliens/direct/sva_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: spiders_v_aliens ", msg)
		_fail += 1


func _steps(g, n: int, held := {}) -> void:
	for i in n:
		g.step({"held": held})


func _tap(g, key: String) -> void:
	g.step({"held": {key: true}, "just": {key: true}})


func _find(g, kind: String, x: float, y: float):
	for o in g.master_layer:
		if not o.is_tilemap() and o.kind == kind and o.x == x and o.y == y:
			return o
	return null


## Park the hero somewhere and stop him.
func _place(g, o, x: float, y: float) -> void:
	L.move_to(o, x, y)
	o.vx = 0.0
	o.vy = 0.0


var _worlds: Array = []


func _play(seed_value := 7):
	var g = L.new(L.PLAY, seed_value)
	_worlds.append(g)
	return g


func _initialize() -> void:
	# MenuState -> Opening01 -> Opening02 -> PlayState on Space
	var g = L.new(L.MENU, 1)
	_worlds.append(g)
	_steps(g, 3)
	_check(g.state == L.MENU, "menu waits for space")
	_tap(g, "space")
	g.step({})
	_check(g.state == L.OPENING1, "space -> opening 1")
	_steps(g, 400)
	_check(g.opening_type.text == L.OPENING1_TEXT, "opening 1 teletypes its full text")
	_tap(g, "space")
	g.step({})
	_check(g.state == L.OPENING2, "space -> opening 2")
	_tap(g, "space")
	g.step({})
	_check(g.state == L.PLAY, "space -> play")

	# Level_AlienShip contents
	_check(g.hero != null and g.hero.x == 496.0 and g.hero.y == 1360.0, "hero starts at (496,1360)")
	_check(g.aliens.size() == 29 and g.spiders.size() == 25 and g.keys.size() == 3, "29 aliens, 25 spiders, 3 keys")
	_check(g.boxes.size() == 100 and g.pickups.size() == 7, "100 boxes, 7 hearts")
	_check(g.machines.size() == 24, "24 machines: 14 portals, 5 cannons, 3 keyboxes, 2 switches")
	var dead := 0
	for a in g.aliens:
		if not a.alive:
			dead += 1
	_check(dead == 4, "4 dead Dentists in the first room")
	_check(g.hero.health == 5 and g.heart_frame(4) == 0, "5 full hearts")

	# Narration: the first room's TextData teletypes into the HUD
	_steps(g, 120)
	_check(g.hud_text.full.begins_with("When I come to"), "first narration shows in HUD")

	# Arrow keys: accelerate 200, cap 100 px/s; the room's top wall stops him at y = 1280
	g = _play()
	var x0: float = g.hero.x
	_steps(g, 30, {"right": true})
	_check(g.hero.x > x0 + 15 and g.hero.vx <= 100.0, "right arrow moves hero (vx capped at 100)")
	_steps(g, 240, {"up": true})
	# (collide runs before motion, so he is drawn up to one frame's move into the wall)
	_check(absf(g.hero.y - 1280.0) < 2.0, "hero stops against the wall above (y=%.2f)" % g.hero.y)
	_check(g.state == L.PLAY, "still playing")

	# Geist mimics the hero's input
	g = _play()
	var gx0: float = g.geist.x
	_steps(g, 20, {"left": true})
	_check(g.geist.x < gx0, "mimeogeist copies the arrow keys")

	# Grab + drag: hold D (grab east) on a box, walk west, the box follows
	g = _play()
	var box = _find(g, "Box", 96.0, 1240.0)
	_place(g, g.hero, 80.0 - 16.0, 1240.0)
	g.step({})
	_place(g, g.hero, 80.0, 1240.0)
	g.step({"held": {"d": true}})
	_check(g.hero.grabbers[L.DIR_E].content == box, "D grabs the box to the east")
	var bx0: float = box.x
	_steps(g, 10, {"d": true, "left": true})
	_check(box.x < bx0, "dragged box follows the hero")
	g.step({})
	_check(g.hero.grabbers[L.DIR_E].content == null, "releasing D drops the box")

	# Grabbing a live Dentist hurts (onGrabDraggable)
	g = _play()
	var alien = null
	for a in g.aliens:
		if a.alive:
			alien = a
			break
	_place(g, g.hero, alien.x - 16.0, alien.y)
	g.step({"held": {"d": true}})
	_check(g.hero.health == 4.0 and g.hero.stun > 0, "grabbing a live alien costs a heart")

	# Portal: grab portal 0 at (400,1400) from the west -> appear east of portal 1 (336,1400)
	g = _play()
	_place(g, g.hero, 384.0, 1400.0)
	g.step({"held": {"d": true}})
	_check(g.hero.x == 352.0 and g.hero.y == 1400.0, "portal teleports to the far side of its twin")

	# Locked portal (336,1200) is off until a key reaches KeyBox (464,1200)
	g = _play()
	var p2 = _find(g, "Portal", 336.0, 1200.0)
	var p3 = _find(g, "Portal", 400.0, 1200.0)
	var kb = _find(g, "KeyBox", 464.0, 1200.0)
	_check(not p2.has_power and not p3.has_power and not kb.has_power, "airlock portals start unpowered")
	var key = g.keys[0]
	_place(g, key, 464.0, 1200.0)
	g.step({})
	_check(kb.has_power and p2.has_power and p3.has_power and not key.exists, "key into keybox powers its portals")

	# SwitchBox toggles its portals
	g = _play()
	var sw = _find(g, "SwitchBox", 528.0, 800.0)
	var p14 = _find(g, "Portal", 544.0, 820.0)
	_place(g, g.hero, 528.0, 780.0)
	g.step({"held": {"s": true}})
	_check(sw.has_power and p14.has_power, "grabbing a switch powers its portals")
	g.step({})
	g.step({"held": {"s": true}})
	_check(not sw.has_power and not p14.has_power, "grabbing it again cuts power")

	# Cannon (1120,860): grab from the west, bullet flies east and drops a Dentist
	g = _play()
	var cannon = _find(g, "Cannon", 1120.0, 860.0)
	_place(g, g.hero, 1104.0, 860.0)
	g.step({"held": {"d": true}})
	_check(g.bullets.size() == 1 and g.bullets[0].vx == 75.0, "cannon fires east at 75 px/s")
	_check(not cannon.has_power, "cannon reboots after firing")
	var target = g.aliens[0]
	_place(g, target, g.bullets[0].x + 40.0, g.bullets[0].y)
	target.ax = 0
	for i in 60:
		g.step({})
		target.ax = 0.0
		target.ay = 0.0
	_check(not target.alive and not g.bullets[0].exists, "bullet kills the Dentist and dies")
	_check(cannon.has_power, "cannon powers back up after 0.5 s")

	# Spiders kill aliens on contact (and die)
	g = _play()
	var sp = g.spiders[0]
	var al = g.aliens[0]
	_place(g, sp, al.x + 10.0, al.y)
	g.step({})
	_check(not al.alive and not sp.exists, "spider kills a Dentist and dies")

	# Heart pickup heals
	g = _play()
	g.hero_hurt(1)
	var heart = g.pickups[0]
	_place(g, g.hero, heart.x - 4.0, heart.y)
	g.step({})
	_check(g.hero.health == 5.0 and not heart.exists, "heart pickup heals")

	# Death: last heart -> GAME OVER -> held space -> menu
	g = _play()
	g.hero.health = 1.0
	g.hero_hurt(1)
	g.step({})
	_check(g.state == L.DEATH, "losing the last heart -> DeathState")
	g.step({"held": {"space": true}})
	g.step({})
	_check(g.state == L.MENU, "space on GAME OVER -> menu")

	# Reaching the Exit wins
	g = _play()
	_place(g, g.hero, g.exit_obj.x + 4.0, g.exit_obj.y + 4.0)
	g.step({})
	g.step({})
	_check(g.state == L.WIN, "touching the exit -> WinState")

	# Long idle run: Dentists that can see the hero chase; nothing explodes
	g = _play()
	var t0 := Time.get_ticks_msec()
	_steps(g, 600)
	var ms := Time.get_ticks_msec() - t0
	print("600 frames idle in %d ms" % ms)
	_check(g.state == L.PLAY or g.state == L.DEATH, "600 idle frames run")

	for w in _worlds:
		w.dispose()
	_worlds.clear()
	g = null
	quit(1 if _fail else 0)
