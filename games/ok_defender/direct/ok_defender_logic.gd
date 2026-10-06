extends RefCounted
## oK Defender: Direct edition simulation.
## A port of tangentstorm/ok-defender `game.k` (oK/iKe, Ludum Dare 49, 2021).
## One step() is one iKe `tick` frame at a fixed 30 Hz. World units are the
## original 320x200 screen pixels. The world is a cylinder `world_w` px around.
##
## The K code is ported verb for verb: terrain bands, humans per tile, aliens
## homing on a target x, tractor beams at depth BAD, phasers, falling humans
## that tumble every 4 frames, and the minimap camera box. The original jam
## build stopped there. The parts marked [tasks.org] finish TODOs from the
## original `tasks.org` spec so the game can be won or lost (see PORT.md).

const FPS := 30
const W := 320
const H := 200

# -- setup (game.k "== setup ==") --
const SEA_LEVEL := 20
const BEAM_RANGE := 32
const HUMAN_W := 4
const HUMAN_H := 6
const ALIEN_W := 28
const ALIEN_H := 22
const SHIP_W := 32
const SHIP_H := 32
const BEAM_W := 12
const BEAM_H := 8
## bad: h - beamRange+seaLevel+#human  (K reads right to left: 200-(32+20+6))
const BAD := H - (BEAM_RANGE + SEA_LEVEL + HUMAN_H)  # 142
const FIB := [1, 1, 2, 3, 5, 8, 13]  # 5{x,+/-2#x}/1 1
const GND_COLORS := [Color("#b58900"), Color("#859900"), Color("#cb4b16")]
## iKe `solarized` palette entries 0..5, used for the six 30 px sky bands.
const SKY := [Color("#002b36"), Color("#073642"), Color("#586e75"),
		Color("#657b83"), Color("#839496"), Color("#93a1a1")]

# -- ship --
const SH_SPD := 8
const SH_YMIN := 18
const SH_YMAX := 146
const SH_START := Vector2(50, 50)
## Opaque part of ship-stop-r.png, used only for the [tasks.org] crash test.
const SHIP_HIT := Rect2(3, 9, 28, 13)

# -- aliens --
const N_AL := 5
const AL_SPD := 1.3
## tgtOfs: -0.5*(#*alien0)-#*human  ->  -0.5*(28-4) = -12
const TGT_OFS := -0.5 * (ALIEN_W - HUMAN_W)
const BM_OFS := Vector2(8, 20)  # beam offset from alien's upper left

# -- phasers --
const PH_SPD := 14  # _shSpd*1.75
const PH_LT := 16
const PH_OFS := Vector2(22, 18)
const PH_W := 4
const PH_H := 1

# -- [tasks.org] completions --
const SPAWN_START := 8 * FPS     # first reinforcement after 8 s
const SPAWN_MIN := 3 * FPS       # interval shrinks to 3 s
const SPAWN_SHRINK := 10         # frames shaved off per spawn
const MAX_ALIENS := 14
const SAFE_FALL := BEAM_RANGE    # falls longer than this kill the human
const ASH_TTL := 3 * FPS
const DROP_SPACING := 6

enum { TITLE, PLAY, GAMEOVER }

var rng := RandomNumberGenerator.new()
var state := TITLE
var f := 0  # iKe frame counter

var world_w := W * 5
var gnd_w: Array[int] = []
var gnd_x: Array[int] = []
var gnd_h: Array[int] = []
var gnd_c: Array[Color] = []

var hu: Array[Vector2] = []    # humans standing on the ground
var fh: Array[Dictionary] = [] # falling humans {pos, y0}
var ash: Array[Dictionary] = [] # [tasks.org] dead humans {pos, ttl}
var fall_rot := 0              # `falling::+|falling` quarter turns (shared)

var sh := SH_START
var sh_d := 1
var thrust := false
var cam_x := 0.0

## aliens: {x, y, hh (holding), ir (in range), be (beam on), tx (target x), real}
var al: Array[Dictionary] = []

var ph: Array[Dictionary] = []  # phasers {pos, dx, tl}

# [tasks.org] score keeping
var carried := 0
var kills := 0
var saved := 0
var lost := 0
var spawn_in := SPAWN_START
var spawn_every := SPAWN_START
var crashed := false
var fire_latch := false  # needs a fresh Space press to leave TITLE/GAMEOVER


func _init(p_state: int = TITLE, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	new_world()
	state = p_state


func new_world() -> void:
	f = 0
	_gen_terrain()
	hu = _spawn_humans()
	fh.clear(); ash.clear(); ph.clear(); al.clear()
	fall_rot = 0
	sh = SH_START; sh_d = 1; thrust = false; cam_x = 0.0
	carried = 0; kills = 0; saved = 0; lost = 0
	spawn_in = SPAWN_START; spawn_every = SPAWN_START
	crashed = false
	for i in N_AL:
		_add_alien(float(rng.randi_range(0, world_w - 1)))


# --- terrain generation -------------------------------------------------------
func _gen_terrain() -> void:
	_shuffle_perm()
	# gndW: {(1+*&worldW<+\x)#x}20*fib@50?#fib
	var picks: Array[int] = []
	for i in 50:
		picks.append(20 * FIB[rng.randi_range(0, FIB.size() - 1)])
	gnd_w.clear()
	var total := 0
	for wv in picks:
		gnd_w.append(wv)
		total += wv
		if total > W * 5:
			break
	world_w = total  # worldW: +/ gndW
	gnd_x.clear(); gnd_h.clear(); gnd_c.clear()
	var x := 0
	for wv in gnd_w:
		gnd_x.append(x)
		x += wv
		# gndH: _seaLevel+20*pn[0.1;0.1;]'?#gndW
		gnd_h.append(int(floor(SEA_LEVEL + 20.0 * pn(0.1, 0.1, rng.randf()))))
		gnd_c.append(GND_COLORS[rng.randi_range(0, GND_COLORS.size() - 1)])


func _spawn_humans() -> Array[Vector2]:
	var r: Array[Vector2] = []
	for i in gnd_w.size():
		r.append(Vector2(gnd_x[i] + 0.5 * (gnd_w[i] - HUMAN_W), ground_top_i(i) - HUMAN_H))
	return r


func tile_at(x: float) -> int:
	var wx := fposmod(x, world_w)
	for i in gnd_w.size():
		if wx < gnd_x[i] + gnd_w[i]:
			return i
	return gnd_w.size() - 1


func ground_top_i(i: int) -> float:
	return H - gnd_h[i]


func ground_top(x: float) -> float:
	return ground_top_i(tile_at(x))


# --- helpers ------------------------------------------------------------------
func wrap_x(x: float) -> float:
	return fposmod(x, world_w)


## Shortest signed x distance from a to b on the cylinder.
func wdelta(a: float, b: float) -> float:
	return fposmod(b - a + world_w * 0.5, world_w) - world_w * 0.5


## overlap:{[whA;whB;xyA;xyB]&/(xyA,xyB)<(xyB,xyA)+whB,whA}, seam-aware in x.
func overlap(pa: Vector2, wha: Vector2, pb: Vector2, whb: Vector2) -> bool:
	var dx := wdelta(pa.x, pb.x)
	return dx < wha.x and -dx < whb.x and pa.y < pb.y + whb.y and pb.y < pa.y + wha.y


func falling_wh() -> Vector2:
	return Vector2(HUMAN_H, HUMAN_W) if fall_rot % 2 else Vector2(HUMAN_W, HUMAN_H)


func humans_left() -> int:
	var n := hu.size() + fh.size() + carried
	for a in al:
		if a.hh and a.real:
			n += 1
	return n


func score() -> int:
	# tasks.org: "your time + #aliens killed - humans killed/abducted" (+ #saved)
	return f / FPS + kills + saved - lost


# --- aliens -------------------------------------------------------------------
func _add_alien(x: float) -> void:
	var a := {"x": x, "y": 0.0, "hh": false, "ir": false, "be": false, "tx": 0.0, "real": false}
	al.append(a)
	_retarget(a)


## alTX: tgtOfs + alX {y@t?&/t:abs[x-y]}\: *:'huXY  (nearest human).
## [tasks.org] prefers a human no other alien is already after.
func _retarget(a: Dictionary) -> bool:
	if hu.is_empty():
		return false
	var taken := {}
	for b in al:
		if b != a and not b.hh:
			taken[int(b.tx - TGT_OFS)] = true
	var best := -1
	var best_d := INF
	for pass_i in 2:
		for i in hu.size():
			if pass_i == 0 and taken.has(int(hu[i].x)):
				continue
			var d := absf(wdelta(a.x, hu[i].x + TGT_OFS))
			if d < best_d:
				best_d = d; best = i
		if best >= 0:
			break
	a.tx = hu[best].x + TGT_OFS
	return true


func _target_human(a: Dictionary) -> int:
	for i in hu.size():
		if absf(wdelta(hu[i].x, a.tx - TGT_OFS)) < 0.5:
			return i
	return -1


# --- tick ---------------------------------------------------------------------
## input: {dx:int, dy:int, fire:bool}
func step(input: Dictionary) -> void:
	var fire: bool = input.get("fire", false)
	match state:
		TITLE, GAMEOVER:
			if fire and not fire_latch:
				if state == GAMEOVER:
					new_world()
				state = PLAY
			fire_latch = fire
			if state != PLAY:
				return
			fire = false  # the start press does not also shoot
		PLAY:
			pass
	f += 1
	var dir := Vector2(signi(input.get("dx", 0)), signi(input.get("dy", 0)))
	thrust = dir.x != 0

	# shD:: (-1; shD;1)[1+*dir]
	if dir.x != 0:
		sh_d = int(dir.x)
	# shXY:: @[wrap shXY+ shSpd*dir; 1; shYMax&shYMin|]
	sh = Vector2(wrap_x(sh.x + SH_SPD * dir.x), clampf(sh.y + SH_SPD * dir.y, SH_YMIN, SH_YMAX))
	# draw: camXY:: wrap camXY+ (shSpd, 0) * dir   (camera locked to the ship)
	cam_x = wrap_x(cam_x + SH_SPD * dir.x)

	for a in al:
		# stage 0: aliens drift down while centering in on target
		if not a.hh and not a.ir:
			if _target_human(a) < 0:
				_retarget(a)  # [tasks.org] target was taken: pick another
			a.x = wrap_x(a.x + AL_SPD * signf(wdelta(a.x, a.tx)))
			a.y = minf(BAD, 1.5 * AL_SPD + a.y)
		# stage 1: engage tractor beams when in range
		a.ir = int(floor(a.y)) == BAD and absf(wdelta(a.x, a.tx)) < 1.0
		if a.ir and not a.hh:
			var hi := _target_human(a)
			if hi >= 0:
				hu.remove_at(hi)
				a.be = true
				a.hh = true
				a.real = true
			else:
				a.ir = false
				_retarget(a)
	# stage 2: aliens holding humans return to space
	var gone: Array[Dictionary] = []
	for a in al:
		if a.hh:
			a.y -= AL_SPD
			if a.y < -ALIEN_H - BEAM_H - BM_OFS.y:  # [tasks.org] abducted
				gone.append(a)
	for a in gone:
		lost += 1
		al.erase(a)

	# move and cull phaser blasts
	var keep: Array[Dictionary] = []
	for p in ph:
		p.pos = Vector2(wrap_x(p.pos.x + p.dx), fposmod(p.pos.y, H))
		p.tl -= 1
		if p.tl >= 1:
			keep.append(p)
	ph = keep

	# falling humans
	for h in fh:
		h.pos.y += 1
	if f % 4 == 0:
		fall_rot = (fall_rot + 1) % 4
	_land_falling()  # [tasks.org]

	_collide()
	_drop_off()      # [tasks.org]
	_spawn_tick()    # [tasks.org]
	_age_ash()

	# (" " in keys) shoot[shXY]/shD   -- fires every tick while held
	if fire:
		ph.append({"pos": Vector2(wrap_x(sh.x + PH_OFS.x), sh.y + PH_OFS.y),
				"dx": float(PH_SPD * sh_d), "tl": PH_LT})

	if crashed or humans_left() == 0:
		state = GAMEOVER
		fire_latch = true


func _collide() -> void:
	# PHvAL: phasers vs aliens; dead aliens holding humans drop their humans
	var dead_al := {}
	var dead_ph := {}
	for pi in ph.size():
		for ai in al.size():
			if overlap(ph[pi].pos, Vector2(PH_W, PH_H), Vector2(al[ai].x, al[ai].y), Vector2(ALIEN_W, ALIEN_H)):
				dead_ph[pi] = true
				dead_al[ai] = true
	if not dead_ph.is_empty():
		var keep_ph: Array[Dictionary] = []
		for pi in ph.size():
			if not dead_ph.has(pi):
				keep_ph.append(ph[pi])
		ph = keep_ph
	if not dead_al.is_empty():
		var keep_al: Array[Dictionary] = []
		for ai in al.size():
			var a: Dictionary = al[ai]
			if not dead_al.has(ai):
				keep_al.append(a)
				continue
			kills += 1
			if a.hh and a.real:
				# fhXY,:: (-tgtOfs;2+#alien0) +/: alXY@&drop
				var p := Vector2(a.x - TGT_OFS, a.y + 2 + ALIEN_H)
				fh.append({"pos": p, "y0": p.y})
		al = keep_al

	# SHvFH: ship vs falling humans (ship catches them)
	var keep_fh: Array[Dictionary] = []
	for h in fh:
		if overlap(sh, Vector2(SHIP_W, SHIP_H), h.pos, falling_wh()):
			carried += 1
		else:
			keep_fh.append(h)
	fh = keep_fh

	# [tasks.org] ship vs alien = game over
	var hx := SHIP_HIT.position.x if sh_d == 1 else SHIP_W - SHIP_HIT.end.x
	var hp := Vector2(wrap_x(sh.x + hx), sh.y + SHIP_HIT.position.y)
	for a in al:
		if overlap(hp, SHIP_HIT.size, Vector2(a.x, a.y), Vector2(ALIEN_W, ALIEN_H)):
			crashed = true


## [tasks.org] "collision detection between ground + falling human: death".
## Short drops (no further than the beam range) land safely instead.
func _land_falling() -> void:
	var keep: Array[Dictionary] = []
	for h in fh:
		var top := ground_top(h.pos.x + HUMAN_W * 0.5)
		if h.pos.y + HUMAN_H < top:
			keep.append(h)
			continue
		var p := Vector2(h.pos.x, top - HUMAN_H)
		if p.y - h.y0 > SAFE_FALL:
			lost += 1
			ash.append({"pos": p, "ttl": ASH_TTL})
		else:
			hu.append(p)
	fh = keep


## [tasks.org] "track whether ship is carrying a human, and if so, drop off on
## ground": fly to the lowest altitude to set carried humans down.
func _drop_off() -> void:
	if carried == 0 or sh.y < SH_YMAX:
		return
	var cx := sh.x + SHIP_W * 0.5 - HUMAN_W * 0.5
	for i in carried:
		var x := wrap_x(cx + (i - (carried - 1) * 0.5) * DROP_SPACING)
		hu.append(Vector2(x, ground_top(x + HUMAN_W * 0.5) - HUMAN_H))
	saved += carried
	carried = 0


## [tasks.org] "spawn more aliens over time".
func _spawn_tick() -> void:
	spawn_in -= 1
	if spawn_in > 0:
		return
	spawn_every = maxi(SPAWN_MIN, spawn_every - SPAWN_SHRINK)
	spawn_in = spawn_every
	if al.size() >= MAX_ALIENS or hu.is_empty():
		return
	var x := 0.0
	for tries in 8:  # keep reinforcements off the visible screen when we can
		x = float(rng.randi_range(0, world_w - 1))
		if absf(wdelta(cam_x + W * 0.5, x)) > W * 0.6:
			break
	_add_alien(x)


func _age_ash() -> void:
	var keep: Array[Dictionary] = []
	for a in ash:
		a.ttl -= 1
		if a.ttl > 0:
			keep.append(a)
	ash = keep


# --- iKe `pn` (ike/noise.js): Ken Perlin's improved noise, scaled to 0..1 ----
## noise.js builds its permutation table at load time with `512#<?256`, so
## every run gets fresh noise. We shuffle one per world from the seeded rng.
var _pp: PackedInt32Array = PackedInt32Array()


func _shuffle_perm() -> void:
	var perm := []
	for i in 256:
		perm.append(i)
	for i in range(255, 0, -1):
		var j := rng.randi_range(0, i)
		var t = perm[i]; perm[i] = perm[j]; perm[j] = t
	_pp = PackedInt32Array(perm + perm)


static func _fade(t: float) -> float:
	return t * t * t * (t * (t * 6 - 15) + 10)


static func _grad(h: int, x: float, y: float, z: float) -> float:
	h &= 15
	var u := x if h < 8 else y
	var v := y if h < 4 else (x if h == 12 or h == 14 else z)
	return (u if h & 1 == 0 else -u) + (v if h & 2 == 0 else -v)


func pn(x: float, y: float, z: float) -> float:
	if _pp.is_empty():
		_shuffle_perm()
	var pp := _pp
	var xi := int(floor(x)) & 255
	var yi := int(floor(y)) & 255
	var zi := int(floor(z)) & 255
	x -= floor(x); y -= floor(y); z -= floor(z)
	var u := _fade(x); var v := _fade(y); var w := _fade(z)
	var a := pp[xi] + yi; var aa := pp[a] + zi; var ab := pp[a + 1] + zi
	var b := pp[xi + 1] + yi; var ba := pp[b] + zi; var bb := pp[b + 1] + zi
	var n := lerpf(lerpf(lerpf(_grad(pp[aa], x, y, z), _grad(pp[ba], x - 1, y, z), u),
			lerpf(_grad(pp[ab], x, y - 1, z), _grad(pp[bb], x - 1, y - 1, z), u), v),
		lerpf(lerpf(_grad(pp[aa + 1], x, y, z - 1), _grad(pp[ba + 1], x - 1, y, z - 1), u),
			lerpf(_grad(pp[ab + 1], x, y - 1, z - 1), _grad(pp[bb + 1], x - 1, y - 1, z - 1), u), v), w)
	return (1.0 + n) / 2.0
