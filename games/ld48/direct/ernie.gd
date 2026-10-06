extends CharacterBody2D
## Ernie Goldsmile, the player. Port of ld48 `ernie.gd` (Godot 3 KinematicBody2D).
## The movement code is the original's, frame for frame: it keeps its own
## velocity `dxy`, adds G every physics tick, and slides.

signal reach_object(body)
signal leave_object(body)

const CURSOR := preload("res://games/ld48/direct/sprites/cursor.png")
const CURSOR_BLOCKED := preload("res://games/ld48/direct/sprites/cursor-blocked.png")

var focus: Node2D # whatever we're looking at
var was_on_floor: bool = false
var dxy: Vector2 = Vector2(0, 0)
const G: Vector2 = Vector2(0, 98)
const SPEED = 150
const JUMP = G * -8
const GROUND_FRICTION = Vector2(0.8, 1)
const AIR_FRICTION = Vector2(0.9, 1)

const QWERTY = {
	'up': KEY_W,
	'lf': KEY_A,
	'dn': KEY_S,
	'rt': KEY_D,
	'ex': KEY_E }

const DVORAK = {  # guess which keyboard layout I use...
	'up': KEY_COMMA,
	'lf': KEY_A,
	'dn': KEY_O,
	'rt': KEY_E,
	'ex': KEY_PERIOD }

var keys = QWERTY
var useDvorak = false
var interacting = false
var has_teleporter = true
var obstructed = false
var _nine_was_down := false


func _exit_tree() -> void:
	# Don't leak the teleporter cursor into the arcade hub.
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


func start_beam():
	$beam.visible = true
	obstructed = null
	update_beam()


func cancel_beam():
	$beam.visible = false
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


func fire(at_point):
	if $beam.visible and not obstructed:
		global_position = at_point
	$beam.visible = false


func update_beam():
	var was_obstructed = obstructed
	# Port: the original used viewport (screen) coordinates, which only matched
	# world coordinates because Ivan's office had no camera. Use world coords.
	var mp = get_global_mouse_position() - global_position  # mouse in relative coords
	$beam.set_point_position(0, Vector2.ZERO)

	$ray.target_position = mp
	$ray.force_raycast_update()
	obstructed = $ray.is_colliding()
	if obstructed: $beam.set_point_position(1, $ray.get_collision_point() - global_position)
	else: $beam.set_point_position(1, mp)

	if obstructed != was_obstructed:
		var cursor = CURSOR
		$beam.default_color = Color.GREEN_YELLOW
		if obstructed:
			cursor = CURSOR_BLOCKED
			$beam.default_color = Color.FIREBRICK
		Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, Vector2(64, 64))


func _input(event):
	# teleporter
	if event is InputEventMouseButton and has_teleporter:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_RIGHT: start_beam()
				MOUSE_BUTTON_LEFT: fire(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_beam()


func _physics_process(_delta):
	if $beam.visible: update_beam()

	# Godot 3: dxy = move_and_slide(dxy + G, Vector2.UP)
	velocity = dxy + G
	move_and_slide()
	dxy = velocity

	var goL = Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(keys['lf'])
	var goR = Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(keys['rt'])

	if is_on_floor() or is_on_wall():
		if is_on_wall(): dxy.x = 0
		if goL: dxy += Vector2.LEFT * SPEED
		if goR: dxy += Vector2.RIGHT * SPEED
	if is_on_floor():
		dxy *= GROUND_FRICTION
	if is_on_floor() or was_on_floor: # "coyote time" jumps
		if Input.is_key_pressed(KEY_SPACE): dxy += JUMP
	if not is_on_floor():
		dxy *= AIR_FRICTION
		# allow small amount of steering in the air
		if goL: dxy += Vector2.LEFT * SPEED / 3
		if goR: dxy += Vector2.RIGHT * SPEED / 3

	# Port: the original reloaded the room on Esc. Esc now belongs to the
	# arcade PauseOverlay, so R restarts the room instead.
	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene.call_deferred()
		set_physics_process(false)
		return

	# Port: the original toggled every frame while 9 was held (and picked the
	# layouts backwards). Toggle once per press.
	var nine := Input.is_key_pressed(KEY_9)
	if nine and not _nine_was_down:
		useDvorak = not useDvorak
		keys = DVORAK if useDvorak else QWERTY
	_nine_was_down = nine

	if Input.is_key_pressed(keys['ex']):
		if focus and !interacting:
			interacting = true
			focus.on_interact_begin()
	elif interacting:
		interacting = false
		if focus: focus.on_interact_end()

	was_on_floor = is_on_floor()


func _on_area_body_entered(body):
	if body == self: return
	reach_object.emit(body)
	focus = body


func _on_area_body_exited(body):
	if body == self: return
	leave_object.emit(body)
	if interacting:
		interacting = false
		focus.on_interact_end()
	focus = null
