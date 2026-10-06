extends SceneTree
## Headless logic checks for the ok_defender direct port.
## Run: godot --headless --path . --script res://tools/test_ok_defender.gd

const L := preload("res://games/ok_defender/direct/ok_defender_logic.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: ok_defender ", msg)
		_fail += 1


func _initialize() -> void:
	# Terrain: gndW tiles are 20*fib widths summing just past 5 screens.
	var g = L.new(L.TITLE, 7)
	var sum := 0
	for wv in g.gnd_w:
		sum += wv
		if wv % 20 != 0 or wv > 260: _check(false, "tile width %d is 20*fib" % wv)
	_check(sum == g.world_w and g.world_w > 1600 and g.world_w - g.gnd_w[-1] <= 1600, "worldW %d just past 1600" % g.world_w)
	_check(L.BAD == 142 and is_equal_approx(L.TGT_OFS, -12.0), "bad=142, tgtOfs=-12 (right-to-left K)")
	_check(g.hu.size() == g.gnd_w.size(), "one human per terrain tile")
	var hgt_ok := true
	for h in g.gnd_h:
		hgt_ok = hgt_ok and h >= 20 and h <= 40
	_check(hgt_ok, "ground heights near seaLevel")
	_check(g.al.size() == L.N_AL, "5 aliens at start")

	# Title waits for a Space press, and holding Space doesn't skip.
	g.step({})
	_check(g.state == L.TITLE and g.f == 0, "title holds")
	g.step({"fire": true})
	_check(g.state == L.PLAY, "space starts play")
	_check(g.ph.is_empty(), "start press doesn't shoot")

	# Ship: 8 px per tick, wraps in x, clamps in y; camera locked.
	var x0: float = g.sh.x
	g.step({"dx": -1})
	_check(is_equal_approx(g.sh.x, fposmod(x0 - 8, g.world_w)), "ship moves 8px left and wraps")
	_check(g.sh_d == -1, "ship faces left")
	_check(is_equal_approx(fposmod(g.sh.x - g.cam_x, g.world_w), 50.0), "camera locked to ship at screen x=50")
	for i in 30:
		g.step({"dy": -1})
	_check(g.sh.y == L.SH_YMIN, "clamped to shYMin")

	# Phasers: spawn every tick while held, 14 px/tick, live 16 ticks.
	g.ph.clear()
	g.step({"fire": true})
	_check(g.ph.size() == 1 and g.ph[0].dx == -14.0, "phaser fires in ship direction")
	g.ph.clear()
	g.step({"fire": true})
	for i in 20:
		g.step({})
	_check(g.ph.is_empty(), "phasers expire")

	# Aliens descend to BAD, engage beams, and carry humans up.
	var g2 = L.new(L.PLAY, 3)
	g2.sh = Vector2(g2.sh.x, L.SH_YMIN)
	var n0: int = g2.hu.size()
	var engaged := false
	for i in 400:
		for a in g2.al:
			# keep the ship out of the way
			pass
		g2.sh = Vector2(fposmod(g2.al[0].x + g2.world_w * 0.5, g2.world_w), L.SH_YMIN)
		g2.step({})
		for a in g2.al:
			if a.hh:
				engaged = true
		if engaged:
			break
	_check(engaged and g2.hu.size() < n0, "an alien beamed up a human")

	# Shooting a carrier drops a falling human, which tumbles.
	var g3 = L.new(L.PLAY, 5)
	var a3: Dictionary = g3.al[0]
	a3.hh = true; a3.be = true; a3.real = true; a3.y = 100.0
	g3.hu.remove_at(0)
	g3.sh = Vector2(fposmod(a3.x - 40, g3.world_w), 100 - 18 + 5)
	g3.sh_d = 1
	for i in 6:
		g3.step({"fire": true})
	_check(g3.kills >= 1 and g3.fh.size() == 1, "shot carrier drops a human")
	# Catch it with the ship.
	var h3: Dictionary = g3.fh[0]
	g3.sh = Vector2(fposmod(h3.pos.x - 10, g3.world_w), h3.pos.y - 10)
	g3.step({})
	_check(g3.carried == 1 and g3.fh.is_empty(), "ship catches falling human")
	# Fly low to drop off.
	var saved0: int = g3.saved
	for i in 30:
		g3.step({"dy": 1})
	_check(g3.saved == saved0 + 1 and g3.carried == 0, "flying low sets the human down")

	# Long fall kills the human (ash).
	var g4 = L.new(L.PLAY, 9)
	g4.al.clear()
	g4.fh.append({"pos": Vector2(10, 40), "y0": 40.0})
	g4.sh = Vector2(800, L.SH_YMIN)
	for i in 200:
		g4.step({})
	_check(g4.lost == 1 and g4.ash.size() <= 1 and g4.fh.is_empty(), "long fall kills the human")

	# Crash into an alien -> game over; space restarts.
	var g5 = L.new(L.PLAY, 11)
	g5.al[0].x = g5.sh.x; g5.al[0].y = g5.sh.y + 5
	g5.step({})
	_check(g5.state == L.GAMEOVER and g5.crashed, "ship vs alien = game over")
	g5.step({"fire": true})
	_check(g5.state == L.GAMEOVER, "held space doesn't restart")
	g5.step({})
	g5.step({"fire": true})
	_check(g5.state == L.PLAY and g5.kills == 0 and not g5.crashed, "fresh space restarts")

	# Seam: overlap works across the wrap.
	_check(g5.overlap(Vector2(g5.world_w - 2, 10), Vector2(4, 4), Vector2(1, 10), Vector2(4, 4)), "overlap across seam")

	# Unattended run ends when every human is gone (nihilistic by design).
	var g6 = L.new(L.PLAY, 13)
	var n := 0
	while g6.state == L.PLAY and n < 30 * 60 * 20:
		g6.sh = Vector2(g6.sh.x, L.SH_YMIN)
		g6.al = g6.al.filter(func(a): return not g6.overlap(g6.sh, Vector2(32, 32), Vector2(a.x, a.y), Vector2(28, 22)))
		g6.step({})
		n += 1
	_check(g6.state == L.GAMEOVER and not g6.crashed and g6.humans_left() == 0, "humans all abducted -> game over (%d s)" % (n / 30))
	_check(g6.al.size() > 0 or g6.lost > 0, "reinforcements/abductions happened")

	print("ok_defender tests: %s" % ("PASS" if _fail == 0 else "%d FAIL" % _fail))
	quit(1 if _fail else 0)
