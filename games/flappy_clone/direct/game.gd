extends Node2D
## Flappy Clone — Direct edition. Renders flappy_logic.gd with the original
## clonybird.png atlas (90 px per Unity unit) and the original scene layout.
## Esc is handled globally by the PauseOverlay autoload (pause / Back to Arcade).

const Logic := preload("res://games/flappy_clone/direct/flappy_logic.gd")
const ATLAS := preload("res://games/flappy_clone/direct/assets/clonybird.png")
const PX := 90.0          ## clonybird.png.meta spritePixelsToUnits
const VIEW_UNITS_H := 6.72  ## GameCamera orthographic size 3.36 * 2
const MAX_HALF_W := 12.0  ## widest view we tile for (about 3.5:1)

## clonybird slices as Godot top-left regions (x, y, w, h).
const SLICES := {
	"bldg3": Rect2(32, 69, 210, 257), "bldg1": Rect2(292, 66, 188, 514),
	"bldg2": Rect2(531, 68, 140, 381), "pipeUp": Rect2(724, 70, 163, 307),
	"pipeDn": Rect2(948, 65, 163, 307), "bldg0": Rect2(40, 365, 146, 345),
	"grass2": Rect2(565, 530, 74, 90), "sky": Rect2(702, 452, 653, 604),
	"cloud0": Rect2(266, 645, 253, 143), "grass0": Rect2(575, 660, 66, 72),
	"cloud1": Rect2(86, 803, 197, 122), "grass1": Rect2(559, 791, 88, 49),
	"birdFlap": Rect2(83, 992, 197, 118), "birdGlide": Rect2(437, 894, 196, 113),
	"rock": Rect2(475, 1096, 24, 22), "ground": Rect2(82, 1170, 655, 90),
}

## Scroll layers from main.unity: layer origin, scrollFactor, xSpacing, and
## [slice, local pos, z] items (z mirrors sorting layer/order).
const LAYERS := [
	{"origin": Vector2(0, 0.23), "factor": 0.05, "spacing": 7.0, "items": [
		["sky", Vector2(0, 0), 0], ["cloud0", Vector2(-4.7, 0.94), 1],
		["cloud1", Vector2(-0.34, 1.55), 1]]},
	{"origin": Vector2(3.15, 1.83), "factor": 0.2, "spacing": 10.0, "items": [
		["bldg3", Vector2(-5.0821, -3.0914), 2], ["bldg2", Vector2(-2.7921, -2.4614), 2],
		["bldg0", Vector2(-0.5321, -3.1814), 2], ["bldg1", Vector2(-7.4821, -2.1714), 2]]},
	{"origin": Vector2(-0.13, -2.99), "factor": 1.0, "spacing": 5.0, "items": [
		["ground", Vector2(0, 0), 5], ["grass0", Vector2(2.0879, 0.6486), 4],
		["rock", Vector2(1.2779, -0.1414), 6], ["grass2", Vector2(-3.1721, 0.7586), 4],
		["grass1", Vector2(5.2679, 0.5286), 4]]},
]
const Z_PIPES := 3
const Z_BIRD := 7

var logic := Logic.new()
var _textures := {}
var _layer_copies: Array = []   ## per layer: Array[Node2D]
var _gate_copies: Array[Node2D] = []
var _bird: Sprite2D
var _last_state := -1

@onready var _world: Node2D = $World


func _ready() -> void:
	for key in SLICES:
		var t := AtlasTexture.new()
		t.atlas = ATLAS
		t.region = SLICES[key]
		_textures[key] = t
	_build_world()
	%TitlePlay.pressed.connect(_on_play)
	%GameOverPlay.pressed.connect(_on_play)
	%BackButton.pressed.connect(GameRegistry.return_to_arcade)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_sync()
	%TitlePlay.grab_focus()


func _sprite(key: String, pos_units: Vector2, z: int, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _textures[key]
	s.position = _to_px(pos_units)
	s.z_index = z
	parent.add_child(s)
	return s


static func _to_px(u: Vector2) -> Vector2:
	return Vector2(u.x * PX, -u.y * PX)


func _build_world() -> void:
	for layer in LAYERS:
		var copies: Array[Node2D] = []
		var n := int(ceil((2.0 * MAX_HALF_W + 18.0) / layer.spacing)) + 2
		for i in n:
			var root := Node2D.new()
			_world.add_child(root)
			for it in layer.items:
				_sprite(it[0], it[1], it[2], root)
			copies.append(root)
		_layer_copies.append(copies)
	var gates := int(ceil((2.0 * MAX_HALF_W + 4.0) / Logic.GATE_SPACING)) + 2
	for i in gates:
		var g := Node2D.new()
		_world.add_child(g)
		_sprite("pipeUp", Vector2(0, -Logic.PIPE_Y), Z_PIPES, g).scale = Vector2(0.8, 1)
		_sprite("pipeDn", Vector2(0, Logic.PIPE_Y), Z_PIPES, g).scale = Vector2(0.8, 1)
		_gate_copies.append(g)
	_bird = _sprite("birdGlide", Logic.BIRD_START, Z_BIRD, _world)
	_bird.scale = Vector2(0.5, 0.5)


func _layout() -> void:
	var size := get_viewport_rect().size
	_world.position = size * 0.5
	var s := size.y / (VIEW_UNITS_H * PX)
	_world.scale = Vector2(s, s)


func _half_width_units() -> float:
	var size := get_viewport_rect().size
	return minf(size.x / size.y * VIEW_UNITS_H * 0.5, MAX_HALF_W)


func _process(delta: float) -> void:
	logic.update(delta)
	_sync()


func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo and event.keycode == KEY_SPACE
	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed and (logic.state == Logic.State.INTRO or logic.state == Logic.State.PLAY):
		logic.jump()
		get_viewport().set_input_as_handled()


func _on_play() -> void:
	logic.play_game()
	_sync()


func _sync() -> void:
	var hw := _half_width_units()
	for li in LAYERS.size():
		var layer: Dictionary = LAYERS[li]
		var sp: float = layer.spacing
		var off: float = logic.scroll * layer.factor
		var ox: float = layer.origin.x - off
		# first copy index whose content (about +/-9 u) reaches the left edge
		var k0 := int(floor((-hw - 9.0 - ox) / sp))
		var copies: Array = _layer_copies[li]
		for i in copies.size():
			copies[i].position = _to_px(Vector2(ox + (k0 + i) * sp, layer.origin.y))
	var gk := int(floor((-hw - 1.0 - Logic.GATE_X + logic.scroll) / Logic.GATE_SPACING))
	for i in _gate_copies.size():
		_gate_copies[i].position = _to_px(Vector2(logic.gate_x(gk + i), 0))

	_bird.visible = logic.bird_visible
	_bird.position = _to_px(logic.bird_pos)
	_bird.texture = _textures["birdFlap" if logic.flap_timer > 0.0 else "birdGlide"]

	var st: int = logic.state
	%TitleScreen.visible = st == Logic.State.TITLE
	%GameOverScreen.visible = st == Logic.State.GAME_OVER
	%ScoreLabel.visible = st != Logic.State.INTRO
	%ScoreText.text = str(logic.score)
	%Hint.visible = st == Logic.State.INTRO
	if st != _last_state:
		_last_state = st
		if st == Logic.State.GAME_OVER:
			%GameOverPlay.grab_focus()
