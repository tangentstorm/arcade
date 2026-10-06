extends KinematicBody2D

signal reach_object(body)
signal leave_object(body)

var focus : Node2D # whatever we're looking at
var was_on_floor: bool = false
var dxy : Vector2 = Vector2(0,0)
const G : Vector2 = Vector2(0,98)
const SPEED = 150
const JUMP  = G * -8
const GROUND_FRICTION = Vector2(0.8,1)
const AIR_FRICTION = Vector2(0.9,1)

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

func start_beam():
	$beam.visible = true
	obstructed = null
	update_beam()

func cancel_beam():
	$beam.visible = false
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


func fire(at_point):
	if $beam.visible and not obstructed:
		position = at_point
	$beam.visible = false


func update_beam():
	var was_obstructed = obstructed

	var vp = get_viewport()
	var mp = vp.get_mouse_position() - position  # mouse in relative coords
	$beam.points[0] = Vector2.ZERO

	$ray.cast_to = mp
	obstructed = $ray.is_colliding()
	if obstructed: $beam.points[1] = $ray.get_collision_point() - position
	else: $beam.points[1] = mp

	if obstructed != was_obstructed:
		var cursor = preload("res://sprites/cursor.png")
		$beam.default_color = Color.greenyellow
		if obstructed:
			cursor = preload("res://sprites/cursor-blocked.png")
			$beam.default_color = Color.firebrick
		Input.set_custom_mouse_cursor(cursor, 0, Vector2(64,64))

func _input(event):
	# teleporter
	if event is InputEventMouseButton and has_teleporter:
		if event.pressed:
			match event.button_index:
				BUTTON_RIGHT: start_beam()
				BUTTON_LEFT: fire(event.position)
		elif event.button_index == BUTTON_RIGHT:
			cancel_beam()



func _physics_process(_delta):
	if $beam.visible: update_beam()

	dxy = move_and_slide(dxy + G, Vector2.UP)

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
		if goL: dxy += Vector2.LEFT * SPEED/3
		if goR: dxy += Vector2.RIGHT * SPEED/3

	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().reload_current_scene()

	if Input.is_key_pressed(KEY_9):
		useDvorak = not useDvorak
		keys = QWERTY if useDvorak else DVORAK

	if Input.is_key_pressed(keys['ex']):
		if focus and !interacting:
			interacting = true
			focus.on_interact_begin()
	elif interacting:
		interacting = false
		focus.on_interact_end()

	was_on_floor = is_on_floor()

func _on_area_body_entered(body):
	emit_signal("reach_object", body)
	focus = body

func _on_area_body_exited(body):
	emit_signal("leave_object", body)
	if interacting:
		interacting = false
		focus.on_interact_end()
	focus = null
