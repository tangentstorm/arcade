extends Control
## Overlap Demo: Direct edition.
## A faithful port of GameSketchLib course w02 `demos/OverlapDemo/OverlapDemo.pde` (Processing, 2011).
## The simulation lives in overlap_logic.gd and steps at a fixed 60 Hz, Processing's default frame rate.
## This script scales the 300×300 sketch to fit and forwards mouse presses/drags in sketch coordinates as
## Processing-style events. It paints the logic's render list with Processing's default 1 px
## black stroke. Esc is handled globally by the PauseOverlay autoload (pausing the tree stops our tick).

const Logic := preload("res://games/overlap_demo/direct/overlap_logic.gd")
const STEP_SEC := 1.0 / Logic.FPS
const STAGE := Vector2(Logic.W, Logic.H)
const USES_MOUSE := true
const USES_KEYS := false
const CODED := "CODED"
## Processing keyCodes for the keys it reports as CODED.
const CODED_KEYS := {KEY_UP: 38, KEY_DOWN: 40, KEY_LEFT: 37, KEY_RIGHT: 39,
	KEY_SHIFT: 16, KEY_CTRL: 17, KEY_ALT: 18}

var world = Logic.new()
var _acc := 0.0
var _buttons := 0       ## held mouse buttons (bitmask by button_index)
var _typed := {}        ## keycode -> char typed on press, reused for its release

@onready var _room: Control = %Room


func _ready() -> void:
	_room.size = STAGE
	_room.draw.connect(_draw_room)
	resized.connect(_fit_room)
	_fit_room()
	_room.queue_redraw()


func _fit_room() -> void:
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	if s <= 0.0:
		return
	_room.scale = Vector2(s, s)
	_room.position = ((size - STAGE * s) * 0.5).round()


func _sketch_xy(event: InputEvent) -> Vector2i:
	var local := _room.make_input_local(event) as InputEventMouse
	return Vector2i(floori(local.position.x), floori(local.position.y))


func _input(event: InputEvent) -> void:
	if not USES_MOUSE:
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index > MOUSE_BUTTON_MIDDLE:
			return
		var p := _sketch_xy(mb)
		var bit := 1 << mb.button_index
		if mb.pressed:
			# A press outside the canvas never reaches the sketch.
			if _buttons == 0 and not Rect2i(Vector2i.ZERO, Vector2i(STAGE)).has_point(p):
				return
			_buttons |= bit
			world.mouse_pressed(p.x, p.y)
		elif _buttons & bit:
			_buttons &= ~bit
			world.mouse_released(p.x, p.y)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _buttons != 0:
		var p := _sketch_xy(mm)
		world.mouse_dragged(p.x, p.y)


## Map a Godot key event to Processing's (key, keyCode). Returns [] for keys we don't report.
func _processing_key(k: InputEventKey) -> Array:
	if CODED_KEYS.has(k.keycode):
		return [CODED, CODED_KEYS[k.keycode]]
	var ch := ""
	if k.pressed and k.unicode >= 32:
		ch = String.chr(k.unicode)
		_typed[k.keycode] = ch
	elif k.keycode >= KEY_A and k.keycode <= KEY_Z:
		# Releases carry no unicode. Java's getKeyChar() follows the current Shift state.
		ch = String.chr(k.keycode)
		if not k.shift_pressed:
			ch = ch.to_lower()
	else:
		ch = _typed.get(k.keycode, "")
	if ch.is_empty():
		return []
	return [ch, int(k.keycode) if k.keycode < 128 else 0]


func _unhandled_key_input(event: InputEvent) -> void:
	if not USES_KEYS:
		return
	var k := event as InputEventKey
	if k == null or k.keycode == KEY_ESCAPE:
		return
	var pk := _processing_key(k)
	if pk.is_empty():
		return
	# OS key-repeat arrives as extra keyPressed events, as it did in Processing.
	if k.pressed:
		world.key_pressed(pk[0], pk[1])
	else:
		world.key_released(pk[0], pk[1])
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_acc = minf(_acc + delta, 0.25)
	var stepped := false
	while _acc >= STEP_SEC:
		_acc -= STEP_SEC
		world.step()
		stepped = true
	if stepped:
		_room.queue_redraw()


func _draw_room() -> void:
	var font := ThemeDB.fallback_font
	for cmd in world.render():
		match cmd[0]:
			"bg":
				_room.draw_rect(Rect2(Vector2.ZERO, STAGE), cmd[1])
			"rect":
				_room.draw_rect(cmd[1], cmd[2])
				_room.draw_rect(cmd[1], Color.BLACK, false, 1.0)
			"text":
				# text(label, x, y): left-aligned, baseline at y
				_room.draw_string(font, cmd[2], cmd[1], HORIZONTAL_ALIGNMENT_LEFT, -1, cmd[3], cmd[4])
