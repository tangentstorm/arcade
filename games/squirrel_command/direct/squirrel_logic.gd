extends RefCounted
## Squirrel Command rules, transcribed 1:1 from the Claude artifact's inline
## <script> (source/squirrel_command.html): reset/startWave/spawn/fire/loop.
## Coordinates are the original 680x440 canvas. Drawing lives in game.gd.

const W := 680.0
const H := 440.0
const CROP_XS := [90.0, 215.0, 340.0, 465.0, 590.0]

var rng := RandomNumberGenerator.new()
var score := 0
var wave := 1
var crops: Array = []      # {x, y, alive}
var squirrels: Array = []  # {x, y, tx, target, sp, runner, ph, leg, dead}
var shots: Array = []      # {x, y, tx, ty, px, py, done}
var booms: Array = []      # {x, y, t, r}
var pops: Array = []       # {x, y, t, v, eat}
var mounds: Array = []     # {x, y}
var to_spawn := 0
var spawn_t := 0.0
var cool := 0.0
var over := false
var wave_msg := 2.0


func _rand() -> float:
	return rng.randf()


func _pick(a: Array):
	return a[int(floor(_rand() * a.size()))]


func reset() -> void:
	score = 0
	wave = 1
	crops = []
	for x in CROP_XS:
		crops.append({"x": x, "y": H - 38.0, "alive": true})
	squirrels = []
	shots = []
	booms = []
	pops = []
	to_spawn = 0
	spawn_t = 0.0
	cool = 0.0
	over = false
	wave_msg = 2.0
	mounds = []
	for i in 6:
		mounds.append({"x": 60.0 + i * 112.0 + _rand() * 40.0, "y": 26.0 + _rand() * 8.0})
	start_wave()


func start_wave() -> void:
	to_spawn = 5 + wave * 3
	spawn_t = 0.6
	wave_msg = 2.0


func alive_crops() -> Array:
	return crops.filter(func(c): return c.alive)


func spawn() -> void:
	var m: Dictionary = _pick(mounds)
	var alive := alive_crops()
	if alive.is_empty():
		return
	var t: Dictionary = _pick(alive)
	var runner := _rand() < 0.12 + wave * 0.02
	squirrels.append({"x": m.x, "y": m.y, "tx": t.x, "target": t,
		"sp": (46.0 + wave * 7.0) * (1.7 if runner else 1.0), "runner": runner,
		"ph": _rand() * 6.28, "leg": 0.0, "dead": false})


## Canvas pointerdown: restart when over, else a shot from the launcher if cooled.
func fire(mx: float, my: float) -> void:
	if over:
		reset()
		return
	if cool > 0.0:
		return
	cool = 0.35
	shots.append({"x": W / 2, "y": H - 14, "tx": mx, "ty": my,
		"px": W / 2, "py": H - 14, "done": false})


## Boom radius curve: grow 0->44 over 0.25s, hold to 0.6s, shrink to 0 by 0.95s.
static func boom_radius(t: float) -> float:
	var r: float
	if t < 0.25:
		r = t / 0.25 * 44.0
	elif t < 0.6:
		r = 44.0
	else:
		r = 44.0 * (1.0 - (t - 0.6) / 0.35)
	return maxf(r, 0.0)


## One requestAnimationFrame tick (the simulation half of loop()).
func step(raw_dt: float) -> void:
	var dt := minf(raw_dt, 0.05)
	cool -= dt
	if wave_msg > 0.0:
		wave_msg -= dt
	if to_spawn > 0 and not over:
		spawn_t -= dt
		if spawn_t <= 0.0:
			spawn()
			to_spawn -= 1
			spawn_t = maxf(0.25, 1.4 - wave * 0.08) * (0.6 + _rand() * 0.8)
	for sh in shots:
		if sh.done:
			continue
		var dx: float = sh.tx - sh.x
		var dy: float = sh.ty - sh.y
		var d := sqrt(dx * dx + dy * dy)
		var v := 430.0 * dt
		sh.px = sh.x
		sh.py = sh.y
		if d <= v:
			sh.done = true
			booms.append({"x": sh.tx, "y": sh.ty, "t": 0.0, "r": 0.0})
		else:
			sh.x += dx / d * v
			sh.y += dy / d * v
	shots = shots.filter(func(s): return not s.done)
	for b in booms:
		b.t += dt
		b.r = boom_radius(b.t)
		if b.t < 0.6:
			for q in squirrels:
				if not q.dead and Vector2(q.x - b.x, q.y - b.y).length() < b.r + 6.0:
					q.dead = true
					var v := 25 if q.runner else 10
					score += v
					pops.append({"x": q.x, "y": q.y, "t": 0.0, "v": v, "eat": false})
	booms = booms.filter(func(b): return b.t < 0.95)
	for p in pops:
		p.t += dt
	pops = pops.filter(func(p): return p.t < 0.8)
	for q in squirrels:
		if q.dead:
			continue
		if not q.target.alive:
			var alive := alive_crops()
			if alive.is_empty():
				continue
			q.target = _pick(alive)
		q.ph += dt * 6.0
		var dx: float = q.target.x - q.x
		var dy: float = q.target.y - q.y
		var d := sqrt(dx * dx + dy * dy)
		if d < 14.0:
			q.target.alive = false
			q.dead = true
			pops.append({"x": q.target.x, "y": q.target.y - 10.0, "t": 0.0, "v": 0, "eat": true})
		else:
			q.x += (dx / d * q.sp + sin(q.ph) * 22.0) * dt
			q.y += dy / d * q.sp * dt
	squirrels = squirrels.filter(func(q): return not q.dead)
	var crops_left := alive_crops().size()
	if crops_left == 0:
		over = true
	if not over and to_spawn == 0 and squirrels.is_empty():
		score += crops_left * 25
		wave += 1
		start_wave()
