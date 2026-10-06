extends Control
## GM Defense — Direct edition.
## Faithful port of tangentstorm/gamemaker-stuff gm2-defense (GameMaker Studio 2, 2017).
## Simulation: gmd_world.gd (60 steps/s, the GMS2 default game speed).
## This script draws r_main (1024x768, black, no views) scaled to fit, and feeds
## Key Press events to the world. Esc is handled globally by the PauseOverlay
## autoload (pausing the tree stops our tick).

const World := preload("res://games/gm_defense/direct/gmd_world.gd")

const SHIP_TEX := preload("res://games/gm_defense/direct/assets/s_ship0_0.png")
const SQUID_TEX := [
	preload("res://games/gm_defense/direct/assets/s_squid_0.png"),
	preload("res://games/gm_defense/direct/assets/s_squid_1.png"),
	preload("res://games/gm_defense/direct/assets/s_squid_2.png"),
	preload("res://games/gm_defense/direct/assets/s_squid_3.png"),
]
const ORIGIN := Vector2(25, 25)  ## both sprites: 50x50, origin 4 (middle centre)
const STEP_SEC := 1.0 / World.SPEED

var world = World.new()
var _acc := 0.0
var _left_pressed := false
var _right_pressed := false

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


## GM Key Press events fire once per press; queue them until the next step so a
## quick tap between steps is never lost.
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_LEFT:
		_left_pressed = true
	elif k.keycode == KEY_RIGHT:
		_right_pressed = true


func _process(delta: float) -> void:
	_acc = minf(_acc + delta, 0.25)
	var stepped := false
	while _acc >= STEP_SEC:
		_acc -= STEP_SEC
		world.step({"left_pressed": _left_pressed, "right_pressed": _right_pressed})
		_left_pressed = false
		_right_pressed = false
		stepped = true
	if stepped:
		_room.queue_redraw()


func _draw_room() -> void:
	_room.draw_rect(Rect2(0, 0, World.W, World.H), Color.BLACK)  # background layer colour
	# Instance layer, creation order: o_ship0, o_squid.
	var s = world.ship
	var sz := SHIP_TEX.get_size()
	var pos := Vector2(s.x - ORIGIN.x * s.image_xscale, s.y - ORIGIN.y).round()
	_room.draw_texture_rect(SHIP_TEX, Rect2(pos, Vector2(sz.x * s.image_xscale, sz.y)), false)
	var q = world.squid
	var tex: Texture2D = SQUID_TEX[int(q.image_index) % SQUID_TEX.size()]
	_room.draw_texture(tex, (Vector2(q.x, q.y) - ORIGIN).round())
