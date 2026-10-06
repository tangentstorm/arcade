extends Control
## Doth Direct — SvA-like pixel tile presentation of silverware Doth-A.
## Esc → PauseOverlay (arcade shell). Letterbox scale via GameRegistry.

const World := preload("res://games/doth/direct/doth_world.gd")
const Tiles := preload("res://games/doth/direct/doth_tiles.gd")

const TILE := Tiles.TILE
const MAP_W := World.MAP_W
const MAP_H := World.MAP_H
const HUD_H := 48
const STAGE_W := MAP_W * TILE          # 1120
const STAGE_H := MAP_H * TILE + HUD_H  # 368

const COL_BG := Color(0.06, 0.07, 0.12)
const COL_FRAME := Color(0.35, 0.45, 0.70)
const COL_HUD := Color(0.10, 0.12, 0.20)
const COL_TEXT := Color(0.85, 0.88, 0.95)
const COL_DIM := Color(0.55, 0.60, 0.72)
const COL_GOLD := Color(0.95, 0.80, 0.25)
const COL_TITLE := Color(0.55, 0.75, 1.0)

var world = World.new()
var _atlas: ImageTexture
var _s := 1.0
var _font: Font

@onready var _room: Control = %Room


func _ready() -> void:
	_atlas = Tiles.build_atlas()
	_font = ThemeDB.fallback_font
	_room.size = Vector2(STAGE_W, STAGE_H)
	_room.draw.connect(_draw_room)
	resized.connect(_fit_room)
	_fit_room()


func _fit_room() -> void:
	_s = minf(size.x / float(STAGE_W), size.y / float(STAGE_H))
	if _s <= 0.0:
		return
	_room.scale = Vector2(_s, _s)
	_room.position = ((size - Vector2(STAGE_W, STAGE_H) * _s) * 0.5).floor()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	if world.state == World.State.TITLE or world.state == World.State.WIN:
		world.handle_title_key(e.keycode)
		_room.queue_redraw()
		return
	var d := _dir_from_key(e)
	if d != Vector2i.ZERO:
		world.try_move(d.x, d.y)
		_room.queue_redraw()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_1:
		world.start_play("starter")
		_room.queue_redraw()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_2:
		world.start_play("overworld")
		_room.queue_redraw()
		get_viewport().set_input_as_handled()


func _dir_from_key(e: InputEventKey) -> Vector2i:
	# Physical WASD + arrows + numpad (doth_2 used keypad 1–9).
	match e.keycode:
		KEY_UP, KEY_W, KEY_KP_8:
			return Vector2i(0, -1)
		KEY_DOWN, KEY_S, KEY_KP_2:
			return Vector2i(0, 1)
		KEY_LEFT, KEY_A, KEY_KP_4:
			return Vector2i(-1, 0)
		KEY_RIGHT, KEY_D, KEY_KP_6:
			return Vector2i(1, 0)
		KEY_KP_7, KEY_HOME:
			return Vector2i(-1, -1)
		KEY_KP_9, KEY_PAGEUP:
			return Vector2i(1, -1)
		KEY_KP_1, KEY_END:
			return Vector2i(-1, 1)
		KEY_KP_3, KEY_PAGEDOWN:
			return Vector2i(1, 1)
		_:
			pass
	# Physical letter keys for Dvorak-friendly WASD positions (same as killem_all).
	match e.physical_keycode:
		KEY_W:
			return Vector2i(0, -1)
		KEY_S:
			return Vector2i(0, 1)
		KEY_A:
			return Vector2i(-1, 0)
		KEY_D:
			return Vector2i(1, 0)
		_:
			return Vector2i.ZERO


func _tile_id(kind: int) -> int:
	match kind:
		World.Kind.WALL:
			return Tiles.Id.WALL
		World.Kind.HERO:
			return Tiles.Id.HERO
		World.Kind.COIN:
			return Tiles.Id.COIN
		World.Kind.GEM:
			return Tiles.Id.GEM
		World.Kind.HEART:
			return Tiles.Id.HEART
		World.Kind.AMMO:
			return Tiles.Id.AMMO
		World.Kind.BOULDER:
			return Tiles.Id.BOULDER
		_:
			return Tiles.Id.FLOOR


func _draw_room() -> void:
	_room.draw_rect(Rect2(0, 0, STAGE_W, STAGE_H), COL_BG)
	match world.state:
		World.State.TITLE:
			_draw_title()
		_:
			_draw_play()


func _draw_title() -> void:
	# Brick field backdrop (inspired by dtitle.cel layout, procedural pixels).
	var brick_src := Tiles.src(Tiles.Id.WALL)
	for y in range(0, STAGE_H, TILE):
		for x in range(0, STAGE_W, TILE):
			_room.draw_texture_rect_region(_atlas, Rect2(x, y, TILE, TILE), brick_src)
	_room.draw_rect(Rect2(80, 60, STAGE_W - 160, STAGE_H - 120), Color(0.05, 0.06, 0.12, 0.82))
	_room.draw_rect(Rect2(80, 60, STAGE_W - 160, STAGE_H - 120), COL_FRAME, false, 3.0)
	_text(STAGE_W * 0.5, 100, 48, "DOTH", COL_TITLE, true)
	_text(STAGE_W * 0.5, 155, 22, "Quest for the Empire", COL_GOLD, true)
	_text(STAGE_W * 0.5, 200, 14, "(c) 1993–1996 Sterling Silverware / Michal Wallace", COL_DIM, true)
	_text(STAGE_W * 0.5, 240, 16, "Direct port of doth_a.pas — silverware", COL_TEXT, true)
	_text(STAGE_W * 0.5, 280, 16, "Enter / Space / 2  —  overworld (dmap1)", COL_TEXT, true)
	_text(STAGE_W * 0.5, 305, 16, "1  —  starter chamber", COL_TEXT, true)
	_text(STAGE_W * 0.5, 335, 14, "Esc — pause / Back to Arcade", COL_DIM, true)


func _draw_play() -> void:
	# Map
	for y in MAP_H:
		for x in MAP_W:
			var k: int = world.cells[world.idx(x, y)]
			var tid := _tile_id(k)
			# Always draw floor under entities.
			if tid != Tiles.Id.FLOOR and tid != Tiles.Id.WALL:
				_room.draw_texture_rect_region(
					_atlas, Rect2(x * TILE, y * TILE, TILE, TILE), Tiles.src(Tiles.Id.FLOOR))
			_room.draw_texture_rect_region(
				_atlas, Rect2(x * TILE, y * TILE, TILE, TILE), Tiles.src(tid))
	# HUD bar (dplay-like: Name / Rank / Gold / Magic / Health)
	var hy := MAP_H * TILE
	_room.draw_rect(Rect2(0, hy, STAGE_W, HUD_H), COL_HUD)
	_room.draw_line(Vector2(0, hy), Vector2(STAGE_W, hy), COL_FRAME, 2.0)
	var line1 := "NaMe: %s    RaNK: %s    map: %s" % [world.name_str, world.rank_str, world.level_id]
	var line2 := "GoLd: %04d   MaGiC: %03d   HeaLTH: %03d/%03d   AmMo: %03d   moves: %d" % [
		world.cash, world.magic, world.health, world.health_max, world.ammo, world.moves]
	_text(12, hy + 8, 13, line1, COL_TEXT, false)
	_text(12, hy + 26, 13, line2, COL_GOLD, false)
	# Message strip
	_room.draw_rect(Rect2(STAGE_W - 420, hy + 4, 410, HUD_H - 8), Color(0.08, 0.09, 0.16, 0.9))
	_text(STAGE_W - 410, hy + 14, 12, world.message, COL_DIM, false)
	if world.state == World.State.WIN:
		_room.draw_rect(Rect2(STAGE_W * 0.25, STAGE_H * 0.35, STAGE_W * 0.5, 80), Color(0, 0, 0, 0.75))
		_text(STAGE_W * 0.5, STAGE_H * 0.35 + 20, 22, "Room cleared!", COL_GOLD, true)
		_text(STAGE_W * 0.5, STAGE_H * 0.35 + 48, 14, "Enter — title", COL_TEXT, true)


func _text(x: float, y: float, size: int, label: String, col: Color, center: bool) -> void:
	if label.is_empty():
		return
	var pos := Vector2(x, y + _font.get_ascent(size))
	if center:
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		pos.x -= w * 0.5
	_room.draw_string(_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
