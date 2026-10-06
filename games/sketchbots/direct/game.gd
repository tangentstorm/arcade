extends Control
## SketchBots — Direct edition.
## Port of GameSketchLib course w01 SketchBots (Processing, ~2011), with a deliberate
## two-player enhancement: orange (WASD / Dvorak ,aoe) and blue (arrow keys).
## Simulation: sketchbots_logic.gd, stepped at a fixed 30 Hz (the sketch's frameRate).
## This script draws the 300×300 sketch scaled to fit and feeds it keyboard input.
## Esc is handled globally by the PauseOverlay autoload (pausing the tree stops our tick).

const Logic := preload("res://games/sketchbots/direct/sketchbots_logic.gd")
const STEP_SEC := 1.0 / Logic.FPS

const TEX_BG := preload("res://games/sketchbots/direct/assets/background.png")
const TEX_ORANGE := {
	Logic.Face.L: preload("res://games/sketchbots/direct/assets/orangeguy-L.png"),
	Logic.Face.R: preload("res://games/sketchbots/direct/assets/orangeguy-R.png"),
	Logic.Face.U: preload("res://games/sketchbots/direct/assets/orangeguy-U.png"),
	Logic.Face.D: preload("res://games/sketchbots/direct/assets/orangeguy-D.png"),
}
const TEX_BLUE := {
	Logic.Face.L: preload("res://games/sketchbots/direct/assets/blueguy-L.png"),
	Logic.Face.R: preload("res://games/sketchbots/direct/assets/blueguy-R.png"),
	Logic.Face.U: preload("res://games/sketchbots/direct/assets/blueguy-U.png"),
	Logic.Face.D: preload("res://games/sketchbots/direct/assets/blueguy-D.png"),
}

var world = Logic.new()
var _acc := 0.0

@onready var _room: Control = %Room


func _ready() -> void:
	_room.size = Vector2(Logic.W, Logic.H)
	_room.draw.connect(_draw_room)
	resized.connect(_fit_room)
	_fit_room()
	_room.queue_redraw()


func _fit_room() -> void:
	var s := minf(size.x / Logic.W, size.y / Logic.H)
	if s <= 0.0:
		return
	_room.scale = Vector2(s, s)
	_room.position = ((size - Vector2(Logic.W, Logic.H) * s) * 0.5).floor()


## Map Godot keys to the tokens handle_key understands.
func _key_token(k: InputEventKey) -> String:
	# Processing `key` is layout-dependent; unicode matches that for letter keys.
	if k.unicode != 0:
		var ch := String.chr(k.unicode).to_lower()
		if ch in [",", "<", "w", "e", "d", "o", "s", "a"]:
			return ch
	match k.keycode:
		KEY_COMMA:
			return ","
		KEY_W:
			return "w"
		KEY_E:
			return "e"
		KEY_D:
			return "d"
		KEY_O:
			return "o"
		KEY_S:
			return "s"
		KEY_A:
			return "a"
		KEY_UP:
			return "up"
		KEY_DOWN:
			return "down"
		KEY_LEFT:
			return "left"
		KEY_RIGHT:
			return "right"
		_:
			return ""


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or k.echo:
		return
	var token := _key_token(k)
	if token.is_empty():
		return
	world.handle_key(token, k.pressed)
	get_viewport().set_input_as_handled()
	_room.queue_redraw()


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
	# image(mBackgroundImage, 0, 0) — 900×300 asset; only the left 300×300 shows.
	_room.draw_texture(TEX_BG, Vector2.ZERO)
	_room.draw_texture(TEX_ORANGE[world.orange_face], Vector2(world.orange_x, world.orange_y))
	_room.draw_texture(TEX_BLUE[world.blue_face], Vector2(world.blue_x, world.blue_y))
