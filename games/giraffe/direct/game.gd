extends Control
## Giraffe — Direct edition. Faithful Pico-8 port (128×128 stage).
## Esc is handled by the arcade PauseOverlay autoload.

const Logic := preload("res://games/giraffe/direct/giraffe_logic.gd")
const MapData := preload("res://games/giraffe/direct/map_data.gd")

const STEP_SEC := 1.0 / Logic.FPS
const BG := Color(0, 0, 0)  # cls(0)

var world = Logic.new()
var _acc := 0.0
var _sprites := {}  ## spr id -> Texture2D

@onready var _room: Control = %Room


func _ready() -> void:
	for sid in [1, 2, 3, 16, 17]:
		_sprites[sid] = load("res://games/giraffe/direct/assets/spr_%d.png" % sid)
	_room.size = Vector2(Logic.W, Logic.H)
	_room.draw.connect(_draw_room)
	resized.connect(_fit_room)
	_fit_room()
	_room.queue_redraw()


func _fit_room() -> void:
	var s := minf(size.x / float(Logic.W), size.y / float(Logic.H))
	if s <= 0.0:
		return
	_room.scale = Vector2(s, s)
	_room.position = ((size - Vector2(Logic.W, Logic.H) * s) * 0.5).floor()


func _process(delta: float) -> void:
	_acc = minf(_acc + delta, 0.25)
	var stepped := false
	while _acc >= STEP_SEC:
		_acc -= STEP_SEC
		world.step(_read_input())
		stepped = true
	if stepped:
		_room.queue_redraw()


func _read_input() -> Dictionary:
	# Pico ⬅️➡️ + ❎ (X). Also WASD / Space / Z per arcade mapping.
	return {
		"left": Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A),
		"right": Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D),
		"jump": Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_Z)
				or Input.is_key_pressed(KEY_X),
	}


func _draw_room() -> void:
	_room.draw_rect(Rect2(Vector2.ZERO, Vector2(Logic.W, Logic.H)), BG)
	# map(0,0,0,0) — draw 16×16 cells from map origin
	for my in MapData.H:
		for mx in MapData.W:
			var tid: int = MapData.TILES[my][mx]
			if tid == 0:
				continue
			var tex: Texture2D = _sprites.get(tid)
			if tex == null:
				continue
			_room.draw_texture(tex, Vector2(mx * MapData.CELL, my * MapData.CELL))
	# spr(frm, hx-ox, hy, 1,1, fx)
	var hero: Texture2D = _sprites.get(world.frame)
	if hero == null:
		return
	var at := Vector2(world.hx - Logic.OX, world.hy)
	if world.flip_x:
		_room.draw_set_transform(at + Vector2(8, 0), 0.0, Vector2(-1, 1))
		_room.draw_texture(hero, Vector2.ZERO)
		_room.draw_set_transform(Vector2.ZERO)
	else:
		_room.draw_texture(hero, at)
