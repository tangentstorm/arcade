extends RefCounted
## Flappy Clone (Direct): simulation in original Unity world units.
## +y is up, the camera is centered on (0, 0), and the view is 6.72 units tall.
## Ported from unitylabs/flappyclone (BirdController.cs, GameWorld.cs,
## Scrolling.cs/ScrollLayer.cs, states/*.cs, main.unity scene values).

enum State { TITLE, INTRO, PLAY, GAME_OVER }

## Scrolling.delta = (-0.05, 0) per frame at 60 fps, ported to units/second.
const SCROLL_SPEED := 3.0
## Physics2D gravity (0, -9.81), gravity scale 1, mass 1, no drag.
const GRAVITY := 9.81
## Unity FixedUpdate rate (Time.fixedDeltaTime = 0.02).
const FIXED_DT := 0.02
## GameWorld.Flap() goes through the BirdController with flapForce 2.5.
const FIRST_FLAP := 2.5
## The bird has two BirdController components (flapForce 2.5 and 5). Both see
## Jump, so each press adds 7.5 to vy. Impulse adds to velocity; it doesn't set it.
const PRESS_FLAP := 7.5

const BIRD_START := Vector2(0.16, 0.15)
const BIRD_RADIUS := 0.29              # CircleCollider2D r 0.58 * scale 0.5
const FLOOR_TOP := -2.55               # floorCollider 15x1 at y -3.05
const CEIL_BOTTOM := 3.31              # ceilCollider 15x1 at y 3.81 (harmless)

const GATE_SPACING := 8.0              # PipeGate ScrollLayer xSpacing
const GATE_X := 4.0                    # pipeUp / pipeDn local x
const PIPE_Y := 2.5                    # pipes centered at y = +/-2.5
const PIPE_HALF := Vector2(1.811 * 0.8 * 0.5, 3.411 * 0.5)
const ENDZONE_DX := 0.75               # endZone at x 4.75 in the gate
const ENDZONE_HALF := Vector2(0.125, 3.0)
const GATE_SCORE := 10

const FLAP_FRAME_TIME := 0.1           # how long the flapping sprite shows

var state: int = State.TITLE
var scroll := 0.0          ## total distance the pipe/ground layer has moved left
var bird_pos := BIRD_START
var bird_vy := 0.0
var bird_visible := false
var score := 0
var flap_timer := 0.0
var _accum := 0.0
var _in_zone := {}         ## gate index -> bool (bird overlapping its endZone)


## Center x (world units) of gate k's pipes. Gates repeat every GATE_SPACING.
func gate_x(k: int) -> float:
	return GATE_X + k * GATE_SPACING - scroll


## Gate indices whose pipes could intersect [x_min, x_max].
func gates_between(x_min: float, x_max: float) -> Array[int]:
	var out: Array[int] = []
	var k0 := int(floor((x_min - PIPE_HALF.x - GATE_X + scroll) / GATE_SPACING))
	var k1 := int(ceil((x_max + PIPE_HALF.x + ENDZONE_DX - GATE_X + scroll) / GATE_SPACING))
	for k in range(k0, k1 + 1):
		out.append(k)
	return out


# --- screen flow (screens.controller) -------------------------------------

## Title/GameOver "Play" button: SetTrigger("PlayGame") -> Intro.
func play_game() -> void:
	if state != State.TITLE and state != State.GAME_OVER:
		return
	state = State.INTRO
	# IntroState: HideScreens, ShowBird, HoldBird, HidePipes (stub), HideScore.
	bird_visible = true
	bird_pos = BIRD_START
	bird_vy = 0.0


## The Jump button (space / tap).
func jump() -> void:
	match state:
		State.INTRO:
			# IntroState fires FirstFlap -> GamePlayState: DropBird, Flap,
			# ShowPipes (stub), score = 0, ShowScore.
			state = State.PLAY
			bird_vy = 0.0
			score = 0
			_flap(FIRST_FLAP)
			_in_zone.clear()
			for k in gates_between(bird_pos.x - 1.0, bird_pos.x + 1.0):
				_in_zone[k] = _overlaps_zone(k)
		State.PLAY:
			_flap(PRESS_FLAP)


func _flap(dv: float) -> void:
	bird_vy += dv
	flap_timer = FLAP_FRAME_TIME


func _game_over() -> void:
	# GameOverState: HideBird, show GameOverScreen.
	state = State.GAME_OVER
	bird_visible = false


# --- per-frame update ------------------------------------------------------

func update(delta: float) -> void:
	# Scrolling runs in every state, as in the original.
	scroll += SCROLL_SPEED * delta
	flap_timer = maxf(0.0, flap_timer - delta)
	if state != State.PLAY:
		_accum = 0.0
		return
	_accum = minf(_accum + delta, 0.25)
	while _accum >= FIXED_DT and state == State.PLAY:
		_accum -= FIXED_DT
		_physics_step(FIXED_DT)


func _physics_step(dt: float) -> void:
	bird_vy -= GRAVITY * dt
	bird_pos.y += bird_vy * dt
	# Ceiling: solid, but colliding with "ceil" doesn't end the game.
	if bird_pos.y + BIRD_RADIUS > CEIL_BOTTOM:
		bird_pos.y = CEIL_BOTTOM - BIRD_RADIUS
		bird_vy = minf(bird_vy, 0.0)
	# Floor: any non-ceil collision is game over.
	if bird_pos.y - BIRD_RADIUS <= FLOOR_TOP:
		_game_over()
		return
	for k in gates_between(bird_pos.x - BIRD_RADIUS, bird_pos.x + BIRD_RADIUS):
		var gx := gate_x(k)
		for py in [-PIPE_Y, PIPE_Y]:
			if _circle_hits_rect(bird_pos, BIRD_RADIUS, Vector2(gx, py), PIPE_HALF):
				_game_over()
				return
		# OnTriggerExit2D: +10 whenever the bird leaves an endZone trigger.
		var inside := _overlaps_zone(k)
		if _in_zone.get(k, false) and not inside:
			score += GATE_SCORE
		_in_zone[k] = inside
	# forget gates that scrolled away
	for k in _in_zone.keys():
		if gate_x(k) + ENDZONE_DX < bird_pos.x - 2.0:
			_in_zone.erase(k)


func _overlaps_zone(k: int) -> bool:
	var c := Vector2(gate_x(k) + ENDZONE_DX, 0.0)
	return _circle_hits_rect(bird_pos, BIRD_RADIUS, c, ENDZONE_HALF)


static func _circle_hits_rect(p: Vector2, r: float, c: Vector2, half: Vector2) -> bool:
	var d := (p - c).abs() - half
	var q := Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0))
	return q.length_squared() < r * r
