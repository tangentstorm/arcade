extends RefCounted
## Flappy Clone (Enhanced): simulation in the Direct edition's Unity world units.
## +y is up, the camera is centered on (0, 0), and the view is 6.72 units tall.
## Gravity, scroll speed, bird size, floor and ceiling match Direct. Each flap
## sets vy instead of adding 7.5, gates are random but fair, and a hit plays out
## as a fall to the ground before the Game Over panel.

enum State { TITLE, READY, PLAY, DYING, OVER }

const SCROLL_SPEED := 3.0
const GRAVITY := 9.81
const FIXED_DT := 1.0 / 120.0
const FLAP_VY := 4.4
const MAX_FALL_VY := -8.0

const BIRD_START := Vector2(-1.6, 0.15)
const BIRD_RADIUS := 0.29
const HIT_RADIUS := 0.24               ## a little forgiving vs the drawn bird
const FLOOR_TOP := -2.55
const CEIL_BOTTOM := 3.31

const PIPE_HALF_W := 0.72
const GAP_HALF := 0.92                 ## Direct's gap half is 0.795
const GAP_MIN := -1.15
const GAP_MAX := 1.6
const GAP_MAX_STEP := 1.5              ## max change between neighbouring gaps
const GATE_SPACING := 5.0
const FIRST_GATE_X := 6.0
const SPAWN_X := 7.5                   ## right of the widest (16:9) view edge
const DESPAWN_X := -8.0

const LAND_BOUNCE := 0.25
const LAND_LINGER := 0.35              ## time on the ground before Game Over
const RESTART_LOCK := 0.45             ## ignore taps right after Game Over

class Gate:
	var x: float
	var gap_y: float
	var scored := false

	func _init(p_x: float, p_gap_y: float) -> void:
		x = p_x
		gap_y = p_gap_y


var state: int = State.TITLE
var time := 0.0
var scroll := 0.0
var bird_pos := BIRD_START
var bird_vy := 0.0
var gates: Array[Gate] = []
var score := 0
var best := 0
var new_best := false
var landed := false
var state_time := 0.0                  ## seconds since the last state change
var rng := RandomNumberGenerator.new()
var _accum := 0.0
var _events: Array[StringName] = []


## Events since the last call: flap, score, hit, land, over, ready.
func take_events() -> Array[StringName]:
	var out := _events
	_events = []
	return out


func can_restart() -> bool:
	return state == State.OVER and state_time >= RESTART_LOCK


## Space / click / tap.
func press() -> void:
	match state:
		State.TITLE:
			_get_ready()
		State.READY:
			_set_state(State.PLAY)
			score = 0
			new_best = false
			_spawn_gate(FIRST_GATE_X)
			_flap()
		State.PLAY:
			_flap()
		State.OVER:
			if can_restart():
				_get_ready()


func _get_ready() -> void:
	_set_state(State.READY)
	bird_pos = BIRD_START
	bird_vy = 0.0
	landed = false
	gates.clear()
	_events.append(&"ready")


func _set_state(s: int) -> void:
	state = s
	state_time = 0.0


func _flap() -> void:
	bird_vy = FLAP_VY
	_events.append(&"flap")


func _spawn_gate(x: float) -> void:
	var gap := 0.0
	if not gates.is_empty():
		var last: float = gates.back().gap_y
		gap = clampf(last + rng.randf_range(-GAP_MAX_STEP, GAP_MAX_STEP), GAP_MIN, GAP_MAX)
	gates.append(Gate.new(x, gap))


func update(delta: float) -> void:
	_accum = minf(_accum + delta, 0.25)
	while _accum >= FIXED_DT:
		_accum -= FIXED_DT
		_step(FIXED_DT)


func _step(dt: float) -> void:
	time += dt
	state_time += dt
	match state:
		State.TITLE, State.READY:
			scroll += SCROLL_SPEED * dt
			bird_pos.y = BIRD_START.y + sin(time * 5.0) * 0.12
		State.PLAY:
			scroll += SCROLL_SPEED * dt
			for g in gates:
				g.x -= SCROLL_SPEED * dt
			if gates.back().x < SPAWN_X - GATE_SPACING:
				_spawn_gate(gates.back().x + GATE_SPACING)
			while gates.size() > 1 and gates[0].x < DESPAWN_X:
				gates.pop_front()
			_fall(dt)
			_check_play_collisions()
		State.DYING:
			_fall(dt)
			if landed and state_time >= LAND_LINGER:
				_game_over()


func _fall(dt: float) -> void:
	if landed:
		return
	bird_vy = maxf(bird_vy - GRAVITY * dt, MAX_FALL_VY)
	bird_pos.y += bird_vy * dt
	if bird_pos.y + BIRD_RADIUS > CEIL_BOTTOM:
		bird_pos.y = CEIL_BOTTOM - BIRD_RADIUS
		bird_vy = minf(bird_vy, 0.0)
	if bird_pos.y - BIRD_RADIUS > FLOOR_TOP:
		return
	bird_pos.y = FLOOR_TOP + BIRD_RADIUS
	if state == State.PLAY:
		_hit()
	if bird_vy < -2.5:
		bird_vy = -bird_vy * LAND_BOUNCE
	else:
		bird_vy = 0.0
		landed = true
		state_time = 0.0
		_events.append(&"land")


func _check_play_collisions() -> void:
	if state != State.PLAY:
		return
	for g in gates:
		if absf(g.x - bird_pos.x) < PIPE_HALF_W + HIT_RADIUS:
			if _hits_pipe(g):
				_hit()
				return
		if not g.scored and g.x + PIPE_HALF_W < bird_pos.x - HIT_RADIUS:
			g.scored = true
			score += 1
			_events.append(&"score")


func _hits_pipe(g: Gate) -> bool:
	var top_c := Vector2(g.x, (g.gap_y + GAP_HALF + CEIL_BOTTOM + 4.0) * 0.5)
	var bot_c := Vector2(g.x, (g.gap_y - GAP_HALF + FLOOR_TOP - 4.0) * 0.5)
	var top_half := Vector2(PIPE_HALF_W, (CEIL_BOTTOM + 4.0 - g.gap_y - GAP_HALF) * 0.5)
	var bot_half := Vector2(PIPE_HALF_W, (g.gap_y - GAP_HALF - FLOOR_TOP + 4.0) * 0.5)
	return _circle_hits_rect(bird_pos, HIT_RADIUS, top_c, top_half) \
		or _circle_hits_rect(bird_pos, HIT_RADIUS, bot_c, bot_half)


func _hit() -> void:
	_set_state(State.DYING)
	_events.append(&"hit")
	if bird_pos.y - BIRD_RADIUS > FLOOR_TOP + 0.01:
		bird_vy = maxf(bird_vy, 0.0) + 1.5


func _game_over() -> void:
	_set_state(State.OVER)
	if score > best:
		best = score
		new_best = score > 0
	_events.append(&"over")


static func _circle_hits_rect(p: Vector2, r: float, c: Vector2, half: Vector2) -> bool:
	var d := (p - c).abs() - half
	var q := Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0))
	return q.length_squared() < r * r
