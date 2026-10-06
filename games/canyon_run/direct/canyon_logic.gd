extends RefCounted
## Canyon Run simulation (no nodes, no input): procedural canyon, player craft,
## bullets, drifting targets, crash / reset. Stage coordinates: 240×320 portrait,
## +y down on screen. World y grows "up the canyon"; `dist` is how far we have flown.
##
## Coastline (band-0) uses the Claude Design genRow walk so collision matches the
## paper-cut waterline painted by canyon_topo.gd (w.rows = w.bands[0].rows).

const STAGE_W := 240.0
const STAGE_H := 320.0
const ROW_H := 4.0                # hit-sample step along the craft (world px)
const PLAYER_Y := 280.0           # craft's screen y (fixed; the canyon scrolls)
const PLAYER_HALF := Vector2(6, 7)
const STEER_SPEED := 110.0        # px/s sideways
const SPEED_MIN := 40.0
const SPEED_CRUISE := 70.0
const SPEED_MAX := 120.0
const ACCEL := 90.0
const BULLET_SPEED := 260.0       # relative to the craft
const FIRE_COOLDOWN := 0.18
const ENEMY_HALF := Vector2(8, 4)
const ENEMY_EVERY := 140.0        # world px between target spawns
const CRASH_HOLD := 1.0           # seconds before a restart is accepted
## Design band-0 channel (normalized width fraction). Matches canyon-run.dc-script.js.
const COAST_WMIN := 0.3
const COAST_WMAX := 0.68
const TWIN_SHOT_DX := 0.028 * STAGE_W  # Design fire(): ±0.028 of width

enum State { READY, PLAY, CRASHED }

var state: int = State.READY
var dist := 0.0
var speed := SPEED_CRUISE
var player_x := STAGE_W * 0.5
var score := 0
var best := 0
var kills := 0
var crash_timer := 0.0
var bullets: Array[Vector2] = []   # world-space (x, world_y)
var enemies: Array = []            # [{pos: Vector2 world, vx: float}]

var _rng := RandomNumberGenerator.new()
var _seed := 0
## Design-style sparse coast rows: {y, c, wd, l, r} with l/r as width fractions.
var _coast_rows: Array = []
var _cooldown := 0.0
var _next_enemy := 0.0


func _init(p_seed: int = 1) -> void:
	_seed = p_seed
	reset()


func reset() -> void:
	_rng.seed = _seed
	_coast_rows = [{
		"y": -700.0,
		"c": 0.5,
		"wd": 0.54,
		"l": 0.23,
		"r": 0.77,
	}]
	dist = 0.0
	speed = SPEED_CRUISE
	player_x = STAGE_W * 0.5
	score = 0
	kills = 0
	crash_timer = 0.0
	bullets.clear()
	enemies.clear()
	_cooldown = 0.0
	_next_enemy = 400.0
	state = State.READY
	_ensure_rows()


## World y of a screen y, and back.
func world_y(screen_y: float) -> float:
	return dist + (STAGE_H - screen_y)


func screen_y(wy: float) -> float:
	return STAGE_H - (wy - dist)


func player_world_y() -> float:
	return world_y(PLAYER_Y)


## Canyon walls (left, right) in stage px at world y — Design band-0 edge.
func walls_at(wy: float) -> Vector2:
	_ensure_to_y(wy)
	return Vector2(_coast_edge(-1, wy) * STAGE_W, _coast_edge(1, wy) * STAGE_W)


## Normalized coast edge (−1 = left, +1 = right). Shared with canyon_topo paint.
func coast_edge(side: int, wy: float) -> float:
	_ensure_to_y(wy)
	return _coast_edge(side, wy)


func coast_rows() -> Array:
	return _coast_rows


func row_count() -> int:
	return _coast_rows.size()


func _ensure_rows() -> void:
	_ensure_to_y(dist + STAGE_H + 400.0)
	var low := dist - 700.0
	while _coast_rows.size() > 4:
		var r1: Dictionary = _coast_rows[1]
		if float(r1.y) >= low:
			break
		_coast_rows.remove_at(0)


func _ensure_to_y(wy: float) -> void:
	var last: Dictionary = _coast_rows[_coast_rows.size() - 1]
	while float(last.y) < wy:
		_gen_coast_row()
		last = _coast_rows[_coast_rows.size() - 1]


func _gen_coast_row() -> void:
	var p: Dictionary = _coast_rows[_coast_rows.size() - 1]
	var y: float = float(p.y) + _rng.randf_range(95.0, 180.0)
	var c: float = float(p.c)
	var wd: float = float(p.wd)
	if _rng.randf() > 0.2:  # hold flat 20% — paper-cut plateaus
		c = clampf(c + _rng.randf_range(-0.085, 0.085), 0.36, 0.64)
		wd = clampf(wd + _rng.randf_range(-0.1, 0.1), COAST_WMIN, COAST_WMAX)
	_coast_rows.append({
		"y": y, "c": c, "wd": wd,
		"l": c - wd * 0.5, "r": c + wd * 0.5,
	})


func _coast_edge(side: int, wy: float) -> float:
	if _coast_rows.is_empty():
		return 0.5
	var r0: Dictionary = _coast_rows[0]
	if wy <= float(r0.y):
		return float(r0.l) if side < 0 else float(r0.r)
	for i in range(1, _coast_rows.size()):
		var a: Dictionary = _coast_rows[i - 1]
		var b: Dictionary = _coast_rows[i]
		if wy <= float(b.y):
			var t: float = (wy - float(a.y)) / maxf(float(b.y) - float(a.y), 0.001)
			if side < 0:
				return float(a.l) + (float(b.l) - float(a.l)) * t
			return float(a.r) + (float(b.r) - float(a.r)) * t
	var L: Dictionary = _coast_rows[_coast_rows.size() - 1]
	return float(L.l) if side < 0 else float(L.r)


func start() -> void:
	if state == State.READY:
		state = State.PLAY


## Called on fire / any key on the ready or crash screen.
func restart_if_ready() -> bool:
	if state == State.CRASHED and crash_timer >= CRASH_HOLD:
		best = max(best, score)
		reset()
		return true
	return false


func fire() -> void:
	if state == State.READY:
		start()
	if state != State.PLAY or _cooldown > 0.0:
		return
	_cooldown = FIRE_COOLDOWN
	var wy := player_world_y() + PLAYER_HALF.y
	# Twin flame darts (Design fire(): px ± 0.028).
	bullets.append(Vector2(player_x - TWIN_SHOT_DX, wy))
	bullets.append(Vector2(player_x + TWIN_SHOT_DX, wy))


## steer: -1..1, throttle: -1 (slow) .. 1 (fast), 0 = return to cruise.
func update(delta: float, steer: float = 0.0, throttle: float = 0.0) -> void:
	match state:
		State.READY:
			if steer != 0.0 or throttle != 0.0:
				start()
			else:
				return
		State.CRASHED:
			crash_timer += delta
			return
	var target_speed := SPEED_CRUISE
	if throttle > 0.0:
		target_speed = SPEED_MAX
	elif throttle < 0.0:
		target_speed = SPEED_MIN
	speed = move_toward(speed, target_speed, ACCEL * delta)
	dist += speed * delta
	player_x = clamp(player_x + steer * STEER_SPEED * delta, 0.0, STAGE_W)
	_cooldown = max(0.0, _cooldown - delta)
	_ensure_rows()
	_update_bullets(delta)
	_update_enemies(delta)
	score = int(dist / 10.0) + kills * 50
	if _hits_wall() or _hits_enemy():
		crash()


func crash() -> void:
	state = State.CRASHED
	crash_timer = 0.0
	best = max(best, score)


func _hits_wall() -> bool:
	var py := player_world_y()
	var y := py - PLAYER_HALF.y
	while y <= py + PLAYER_HALF.y:
		var w := walls_at(y)
		if player_x - PLAYER_HALF.x < w.x or player_x + PLAYER_HALF.x > w.y:
			return true
		y += ROW_H
	return false


func _hits_enemy() -> bool:
	var p := Vector2(player_x, player_world_y())
	for e in enemies:
		var d: Vector2 = (e.pos - p).abs()
		if d.x < ENEMY_HALF.x + PLAYER_HALF.x and d.y < ENEMY_HALF.y + PLAYER_HALF.y:
			return true
	return false


func _update_bullets(delta: float) -> void:
	var keep: Array[Vector2] = []
	for b in bullets:
		b.y += (BULLET_SPEED + speed) * delta
		var hit := false
		for e in enemies:
			var d: Vector2 = (e.pos - b).abs()
			if d.x < ENEMY_HALF.x + 2 and d.y < ENEMY_HALF.y + 4:
				enemies.erase(e)
				kills += 1
				hit = true
				break
		if hit:
			continue
		var w := walls_at(b.y)
		if b.x < w.x or b.x > w.y or screen_y(b.y) < -8.0:
			continue
		keep.append(b)
	bullets = keep


func _update_enemies(delta: float) -> void:
	# Spawn just above the top edge, inside the channel.
	var top := dist + STAGE_H + 16.0
	while _next_enemy < top:
		var w := walls_at(_next_enemy)
		if w.y - w.x > ENEMY_HALF.x * 4:
			var x := _rng.randf_range(w.x + ENEMY_HALF.x + 2, w.y - ENEMY_HALF.x - 2)
			var vx := _rng.randf_range(20.0, 45.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
			enemies.append({"pos": Vector2(x, _next_enemy), "vx": vx})
		_next_enemy += ENEMY_EVERY * _rng.randf_range(0.7, 1.3)
	var keep := []
	for e in enemies:
		if screen_y(e.pos.y) > STAGE_H + 16.0:
			continue
		e.pos.x += e.vx * delta
		var w := walls_at(e.pos.y)
		if e.pos.x - ENEMY_HALF.x < w.x:
			e.pos.x = w.x + ENEMY_HALF.x
			e.vx = absf(e.vx)
		elif e.pos.x + ENEMY_HALF.x > w.y:
			e.pos.x = w.y - ENEMY_HALF.x
			e.vx = -absf(e.vx)
		keep.append(e)
	enemies = keep
