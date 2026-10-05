extends Control
## Invader Sketch — Direct edition.
## Faithful port of GameSketchLib course w02 InvaderSketch (Processing, 2011).
## Simulation: invader_logic.gd, stepped at a fixed 60 Hz (Processing's default frameRate).
## This script draws the 640x480 sketch scaled to fit and feeds it keyboard input.
## Esc is handled globally by the PauseOverlay autoload (pausing the tree stops our tick).

const Logic := preload("res://games/invader_sketch/direct/invader_logic.gd")
const SHEET := preload("res://games/invader_sketch/direct/assets/invaders.png")
const STEP_SEC := 1.0 / Logic.FPS
const LINK_URL := "http://gamesketchlib.org"

var world = Logic.new(Logic.MENU)
var _acc := 0.0
var _just: Array = []
var _link_rect := Rect2()
var _link_hover := false

@onready var _room: Control = %Room


func _ready() -> void:
	_room.size = Vector2(Logic.W, Logic.H)
	_room.draw.connect(_draw_room)
	resized.connect(_fit_room)
	_fit_room()


func _fit_room() -> void:
	var s := minf(size.x / Logic.W, size.y / Logic.H)
	if s <= 0.0:
		return
	_room.scale = Vector2(s, s)
	_room.position = ((size - Vector2(Logic.W, Logic.H) * s) * 0.5).floor()


## GsKeys.setKeyDown(): justPressed only on the initial press, not on key repeat.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_SPACE:
			_just.append("space")
		KEY_R:
			_just.append("r")
		_:
			return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_acc = minf(_acc + delta, 0.25)
	var stepped := false
	while _acc >= STEP_SEC:
		_acc -= STEP_SEC
		world.step(_read_input())
		_just.clear()  # GsKeys.update(): justPressed cleared after every frame
		stepped = true
	_update_link_hover()
	if stepped:
		_room.queue_redraw()


func _read_input() -> Dictionary:
	# GsKeys.goW()/goE(): arrows, WASD, and Dvorak (A / E)
	return {
		"just": _just.duplicate(),
		"left": Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A),
		"right": Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
				or Input.is_key_pressed(KEY_E),
	}


## MenuState.mouseMoved(): hover underline + hand cursor over the GsLink.
## The original click() had link() commented out, so clicking does nothing.
func _update_link_hover() -> void:
	var hover: bool = world.state == Logic.MENU and _link_rect.has_point(_room.get_local_mouse_position())
	if hover != _link_hover:
		_link_hover = hover
		_room.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover else Control.CURSOR_ARROW
		_room.queue_redraw()


# --- rendering ---------------------------------------------------------------
func _cell_rect(i: int) -> Rect2:
	return Rect2((i % 4) * Logic.CELL, (i / 4) * Logic.CELL, Logic.CELL, Logic.CELL)


func _draw_sprite(o) -> void:
	if not o.visible:
		return
	var src := _cell_rect(o.sheet_cell())
	if o.degrees == 0:
		_room.draw_texture_rect_region(SHEET, Rect2(o.x, o.y, Logic.CELL, Logic.CELL), src)
	else:
		var half := Vector2(o.w, o.h) * 0.5
		_room.draw_set_transform(Vector2(o.x, o.y) + half, deg_to_rad(o.degrees))
		_room.draw_texture_rect_region(SHEET, Rect2(-half, Vector2(Logic.CELL, Logic.CELL)), src)
		_room.draw_set_transform(Vector2.ZERO)


## GsText: textAlign(CENTER), baseline at y.
func _text(label: String, x: float, y: float, c: Color, fs: int) -> Rect2:
	var font := get_theme_default_font()
	var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(x - sz.x * 0.5, y)
	_room.draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return Rect2(pos.x, y - font.get_ascent(fs), sz.x, font.get_height(fs))


func _draw_room() -> void:
	_room.draw_rect(Rect2(0, 0, Logic.W, Logic.H), Color.BLACK)  # background(0)
	var cx := Logic.W / 2.0
	match world.state:
		Logic.MENU:
			_text("InvaderSketch!", cx, 100, world.crazy_color, 48)
			_text("Part of the GameSketchLib Tutorial Series", cx, 150, Color("#CCCCCC"), 12)
			var link_c := Color("#9999FF")
			_link_rect = _text("www.GameSketchLib.org", cx, 200, link_c, 18)
			if _link_hover:
				var ly := 202.0
				_room.draw_line(Vector2(_link_rect.position.x, ly), Vector2(_link_rect.end.x, ly), link_c)
			_text("Use the Arrow Keys to Move, Space to Shoot", cx, 300, Color.WHITE, 18)
			_text("Press Space to Start", cx, 360, Color("#CCCCCC"), 18)
		Logic.PLAY:
			for g in world.render_groups():
				for o in g:
					if o.exists:
						_draw_sprite(o)
		Logic.GAMEOVER:
			_text("Game Over!", cx, 100, Color.WHITE, 18)
			_text("Press space to Restart", cx, 150, Color("#CCCCCC"), 12)
		Logic.WIN:
			_text("You Won!", cx, 100, Color.WHITE, 18)
			_text("Press space to Restart", cx, 150, Color("#CCCCCC"), 12)
