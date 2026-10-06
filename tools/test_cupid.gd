extends SceneTree
## Headless logic checks for the cupid direct port.
## Run: godot --headless --path . --script res://tools/test_cupid.gd

const L := preload("res://games/cupid/direct/cupid_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: cupid ", msg)
		_fail += 1


## Arrow lands on this person (onCollision), bypassing whoever else overlaps.
func _hit(g, p) -> void:
	g.arrow_exists = true
	g._on_collision(p)


func _step_n(g, n: int, input := {}) -> void:
	for i in n:
		g.step(input)


func _initialize() -> void:
	# Title waits for Space or a click.
	var g = L.new(L.TITLE, 3)
	g.step({})
	_check(g.state == L.TITLE, "title holds")
	g.step({"start": true})
	_check(g.state == L.PLAY, "space starts play")

	# GameState(): 10 people, each symbol on exactly two, spaced GAME_W/11 apart.
	_check(g.people.size() == 10, "10 people")
	var counts := {}
	var images := {}
	for p in g.people:
		counts[p.symbol] = counts.get(p.symbol, 0) + 1
		images[p.image] = true
	var pairs := counts.size() == 5
	for k in counts:
		pairs = pairs and counts[k] == 2 and k >= 0 and k < 5
	_check(pairs, "symbols 0..4, two of each")
	_check(images.size() == 10, "each person has its own image")
	var spaced := true
	for i in g.people.size():
		spaced = spaced and g.people[i].x == (i + 1) * 163
	_check(spaced, "people spaced at (i+1)*163")
	var speeds := true
	for p in g.people:
		speeds = speeds and p.speed >= 0.95 - 0.001 and p.speed <= 1.45 + 0.001 and p.y == 260
	_check(speeds, "walk speeds in 1.25 +- 0.3, y = 260")
	_check(is_equal_approx(g.scroll_x, -8.0), "camera starts centred on cupid (scroll -8)")
	_check(g.clouds_left == 5, "5 rain clouds")

	# Rain: one drop per cloud per frame.
	g.step({"stage_x": 336, "stage_y": 100})
	_check(g.rain_count() == 5, "5 drops after one frame")

	# Cupid flies toward the mouse at (dx * 2.5) px/s and turns to face it.
	var x0: float = g.cx
	g.step({"stage_x": 0, "stage_y": 100})
	_check(g.cx < x0 and not g.c_right, "cupid flies left toward the mouse")
	_step_n(g, 400, {"stage_x": 600, "stage_y": 100})
	_check(g.c_right, "cupid faces right")
	_check(g.scroll_x < -8.0, "camera follows cupid right")

	# People walk speed px per frame and bounce off the world edges.
	var p0 = g.people[0]
	p0.stopped = false
	p0.right = false
	p0.x = 0.5
	g._update_person(p0)
	_check(p0.x == 0 and p0.right, "person bounces off the left edge")

	# Clicking drops an arrow from cupid's bow.
	g = L.new(L.PLAY, 5)
	g.step({"stage_x": g.cx + g.scroll_x + 80, "stage_y": 100})
	g.step({"stage_x": g.cx + g.scroll_x + 80, "stage_y": 100, "click": true})
	_check(g.arrow_exists, "click shoots an arrow")
	_check(g.c_right and g.ax == int(g.cx_prev_shot()) and g.ay == 55 + 72, "arrow starts at bow (cupid + 42, 72)")
	var gl = L.new(L.PLAY, 5)
	gl.step({"stage_x": 0, "stage_y": 100})
	gl.step({"stage_x": 0, "stage_y": 100, "click": true})
	_check(not gl.c_right and gl.ax == int(gl.cx + 72 - 42), "facing left: arrow at cupid + width - 42")
	# overlaps(): the falling arrow hits whoever it's over.
	var ph = L.new(L.PLAY, 5)
	var tgt = ph.people[0]
	ph.arrow_exists = true
	ph.ax = tgt.x + 40
	ph.ay = tgt.y + 10
	ph._overlap_people()
	_check(not ph.arrow_exists and ph.last_hit != null and ph.last_hit.stopped, "arrow over a walker hits")
	_check(g.cupid_anim.name == "shoot", "shoot animation plays")
	_step_n(g, 3)
	_check(g.cupid_anim.name == "shoot", "shoot still playing")
	_step_n(g, 40)
	_check(g.cupid_anim.name == "flight", "back to flight after 4 frames at 12 fps")
	_check(not g.arrow_exists, "arrow gone below the stage")
	# A second click while an arrow is in the air is ignored.
	g.step({"click": true})
	var y1: float = g.ay
	g.step({"click": true})
	_check(g.ay > y1, "click while arrow flies doesn't re-shoot")

	# Matching pair.
	g = L.new(L.PLAY, 9)
	var a = null
	var b = null
	var c = null
	for p in g.people:
		if a == null:
			a = p
		elif p.symbol == a.symbol and b == null:
			b = p
		elif p.symbol != a.symbol and c == null:
			c = p
	_hit(g, c)
	_check(c.stopped and c.marked and g.last_hit == c, "first hit stops the person and shows the bubble")
	_hit(g, c)
	_check(g.last_hit == c and not g.arrow_exists, "hitting the same person again just eats the arrow")
	_hit(g, a)
	_check(g.bad_icon.visible and g.icon_showing and g.last_hit == null, "mismatch shows the broken heart")
	g.step({"click": true})
	_check(not g.arrow_exists, "no shooting while the match icon animates")
	_step_n(g, int(1.5 * L.FPS) + 2)
	_check(not g.icon_showing and g.bad_icon.visible, "icon done; stays on its last frame (visible=false commented out)")
	_check(not a.stopped and not c.stopped and not a.marked, "both walkers resume after 1500 ms")

	_hit(g, a)
	_hit(g, b)
	_check(g.good_icon.visible and g.clouds_left == 4, "match: heart + one less rain cloud")
	_check(is_equal_approx(g.rain_volume, 0.4), "rain loop 0.1 quieter")
	_check(a.exists and b.exists, "couple waits for the timer")
	_step_n(g, int(1.5 * L.FPS) + 2)
	_check(not a.exists and not b.exists and g.couples_left == 4, "couple dissolves after 1500 ms")

	# Win after 5 couples.
	for s in 5:
		var pair: Array = []
		for p in g.people:
			if p.exists and not p.stopped and (pair.is_empty() or p.symbol == pair[0].symbol):
				pair.append(p)
			if pair.size() == 2:
				break
		if pair.size() == 2:
			_hit(g, pair[0])
			_hit(g, pair[1])
			_step_n(g, int(1.5 * L.FPS) + 2)
	_check(g.state == L.WON and g.couples_left == 0 and g.remaining() == 0, "YOU WON after 5 couples")
	_check(g.clouds_left == 0 and g.rain_gain() < 0.001, "the storm has cleared")
	g.step({"next_level": true})
	_check(g.clouds_left == -1 and is_equal_approx(g.rain_volume, 0.5), "N: music level wraps at 6")
	g.step({"start": true})
	_check(g.state == L.PLAY and g.people.size() == 10, "space plays again")

	print("cupid: %s" % ("OK" if _fail == 0 else "%d failures" % _fail))
	quit(1 if _fail else 0)
