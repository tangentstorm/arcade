extends Control
## Kill 'Em All — Direct edition.
## Faithful port of tangentstorm/gamemaker-stuff killem-all.gmx (GM:S 1.x).
## Simulation: ka_world.gd (30 steps/s, room0's room speed).
## This script draws room0 (1024x768, colour 1835008, no views) scaled to fit,
## and reads input. Esc is handled globally by the PauseOverlay autoload
## (pausing the tree stops our tick).

const World := preload("res://games/killem_all/direct/ka_world.gd")
const GMFont := preload("res://games/killem_all/direct/ka_font.gd")

const SHIP_TEX := preload("res://games/killem_all/direct/assets/sprite1_0.png")
const BLAST_TEX := preload("res://games/killem_all/direct/assets/sprite0_0.png")
const BULLET_TEX := preload("res://games/killem_all/direct/assets/bullet_0.png")
const FONT_TEX := preload("res://games/killem_all/direct/assets/fntConsolas.png")
const SHIP_ORIGIN := Vector2(32, 32)    ## sprite1 / sprite0: 64x64, origin (32,32)
const BULLET_ORIGIN := Vector2(4, 4)    ## bullet: 8x8, origin (4,4)
## room0 <colour>1835008</colour> = BGR $1C0000 -> RGB (0, 0, 28)
const ROOM_COLOR := Color8(0, 0, 28)
const STEP_SEC := 1.0 / World.SPEED

## step.gml: LKEY = ord('A'), RKEY = ord('E'), UKEY = 188 (','), DKEY = ord('O').
## Those are a Dvorak typist's WASD. We read them by *physical* position (W A S D
## on a US layout, so they land under the same fingers on any layout), plus the
## literal keycodes the GML names, plus arrows.
const KEYS := {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"up": [KEY_W, KEY_UP],
	"down": [KEY_S, KEY_DOWN],
}
const LITERAL_KEYS := {"left": KEY_A, "right": KEY_E, "up": KEY_COMMA, "down": KEY_O}

var world = World.new()
var _acc := 0.0

@onready var _room: Control = %Room


func _ready() -> void:
	_room.size = Vector2(World.W, World.H)
	_room.draw.connect(_draw_room)
	resized.connect(_fit_room)
	_fit_room()


func _fit_room() -> void:
	var s := minf(size.x / World.W, size.y / World.H)
	if s <= 0.0:
		return
	_room.scale = Vector2(s, s)
	_room.position = ((size - Vector2(World.W, World.H) * s) * 0.5).floor()


func _process(delta: float) -> void:
	_acc = minf(_acc + delta, 0.25)
	var stepped := false
	while _acc >= STEP_SEC:
		_acc -= STEP_SEC
		world.step(_read_input())
		stepped = true
	if stepped:
		_room.queue_redraw()


func _dir_held(name: String) -> bool:
	for k in KEYS[name]:
		if Input.is_physical_key_pressed(k):
			return true
	return Input.is_key_pressed(LITERAL_KEYS[name])


func _read_input() -> Dictionary:
	return {
		"left": _dir_held("left"),
		"right": _dir_held("right"),
		"up": _dir_held("up"),
		"down": _dir_held("down"),
		"fire": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"mouse": _room.get_local_mouse_position(),
	}


func _draw_room() -> void:
	_room.draw_rect(Rect2(0, 0, World.W, World.H), ROOM_COLOR)
	# depth 0, creation order: objShip, objBlast, then bullets as created.
	_room.draw_texture(SHIP_TEX, (Vector2(world.ship_x, world.ship_y) - SHIP_ORIGIN).round())
	# image_angle is CCW on screen (GM, y down); Godot rotation is CW.
	_room.draw_set_transform(Vector2(world.blast_x, world.blast_y), -deg_to_rad(world.blast_angle))
	_room.draw_texture(BLAST_TEX, -SHIP_ORIGIN)
	_room.draw_set_transform(Vector2.ZERO)
	for b in world.bullets:
		_room.draw_texture(BULLET_TEX, (Vector2(b.x, b.y) - BULLET_ORIGIN).round())
	# events Draw -> mousepos.gml (replaces drawing spr_mouse).
	_draw_text(Vector2(10, 10), "x:%d, y:%d" % [floori(world.mouse.x), floori(world.mouse.y)])


## draw_text with fntConsolas, c_white: GM 1.x places each glyph cell at the
## line top, offset by its x bearing, and advances by shift.
func _draw_text(at: Vector2, text: String) -> void:
	var pen := at.x
	for i in text.length():
		var g: Array = GMFont.GLYPHS.get(text.unicode_at(i), GMFont.GLYPHS[32])
		_room.draw_texture_rect_region(FONT_TEX,
				Rect2(pen + g[5], at.y, g[2], g[3]), Rect2(g[0], g[1], g[2], g[3]))
		pen += g[4]
