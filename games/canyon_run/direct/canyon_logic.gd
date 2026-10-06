extends RefCounted
## Canyon Run simulation (no nodes, no input): procedural canyon, player craft,
## bullets, drifting targets, crash / reset. Stage coordinates: 240×320 portrait,
## +y down on screen. World y grows "up the canyon"; `dist` is how far we have flown.

const STAGE_W := 240.0
const STAGE_H := 320.0
const ROW_H := 4.0                # canyon is sampled every 4 world px
const PLAYER_Y := 280.0           # craft's screen y (fixed; the canyon scrolls)
const PLAYER_HALF := Vector2(6, 7)
const STEER_SPEED := 110.0        # px/s sideways
const SPEED_MIN := 40.0
const SPEED_CRUISE := 70.0
const SPEED_MAX := 120.0
const ACCEL := 90.0
const BULLET_SPEED := 260.0       # relative to the craft
const FIRE_COOLDOWN := 0.18
const RUNWAY_ROWS := 60           # straight, wide opening stretch
const WIDTH_START := 170.0
const WIDTH_MIN := 70.0
const MARGIN := 8.0               # min rock on each side of the channel
const ENEMY_HALF := Vector2(8, 4)
const ENEMY_EVERY := 140.0        # world px between target spawns
const CRASH_HOLD := 1.0           # seconds before a restart is accepted

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
var _rows: Dictionary = {}         # row index -> Vector2(left, right)
var _center := STAGE_W * 0.5
var _target := STAGE_W * 0.5
var _gen_row := -1
var _cooldown := 0.0
var _next_enemy := 0.0


func _init(p_seed: int = 1) -> void:
	_seed = p_seed
	reset()


func reset() -> void:
	_rng.seed = _seed
	_rows.clear()
	_center = STAGE_W * 0.5
	_target = _center
	_gen_row = -1
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


## Canyon walls (left, right) at world y.
func walls_at(wy: float) -> Vector2:
	var i := int(floor(wy / ROW_H))
	_generate_to(i)
	return _rows.get(max(i, 0), Vector2(MARGIN, STAGE_W - MARGIN))


func row_count() -> int:
	return _rows.size()


func _ensure_rows() -> void:
	_generate_to(int(ceil((dist + STAGE_H) / ROW_H)) + 2)
	# Drop rows well below the screen.
	var low := int(floor(dist / ROW_H)) - 8
	for k in _rows.keys():
		if k < low:
			_rows.erase(k)


func _generate_to(i: int) -> void:
	while _gen_row < i:
		_gen_row += 1
		var r := _gen_row
		var width: float
		if r < RUNWAY_ROWS:
			width = WIDTH_START
			_center = STAGE_W * 0.5
		else:
			# Narrow slowly with distance, with a gentle pulse for pinch points.
			var base: float = max(WIDTH_MIN, WIDTH_START - (r - RUNWAY_ROWS) * ROW_H / 60.0)
			width = base + sin((r - RUNWAY_ROWS) * 0.045) * 22.0
			width = max(WIDTH_MIN, width)
			if r % 45 == 0:
				_target = _rng.randf_range(MARGIN + width * 0.5, STAGE_W - MARGIN - width * 0.5)
			_center = move_toward(_center, _target, 1.2)
		var half := width * 0.5
		_center = clamp(_center, MARGIN + half, STAGE_W - MARGIN - half)
		_rows[r] = Vector2(_center - half, _center + half)


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
	bullets.append(Vector2(player_x, player_world_y() + PLAYER_HALF.y))


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
