extends Control
## Toroidal Zombie Herder — Direct edition.
## Faithful port of tangentstorm/gamemaker-stuff toroidal-zombie-herder.gmx (GM:S 1.x).
## Simulation: tzh_world.gd (30 steps/s, like the original room speed).
## This script draws room0 (1024x768, black, no views) scaled to fit, and reads input.
## Esc is handled globally by the PauseOverlay autoload (pausing the tree stops our tick).

const World := preload("res://games/toroidal_zombie_herder/direct/tzh_world.gd")

const TEX := {
	World.WALL: preload("res://games/toroidal_zombie_herder/direct/assets/spr_wall_0.png"),
	World.HERO: preload("res://games/toroidal_zombie_herder/direct/assets/spr_hero_0.png"),
	World.ZOMBIE: preload("res://games/toroidal_zombie_herder/direct/assets/spr_zombie_0.png"),
	World.COIN: preload("res://games/toroidal_zombie_herder/direct/assets/coin_0.png"),
	World.TRAP: preload("res://games/toroidal_zombie_herder/direct/assets/spr_trap_0.png"),
}
const ORIGIN := {
	World.WALL: Vector2(16, 16), World.HERO: Vector2(16, 16), World.ZOMBIE: Vector2(16, 16),
	World.COIN: Vector2(4, 4), World.TRAP: Vector2(16, 16),
}
## Draw order: obj_coin has depth 5 (behind); everything else depth 0.
const DRAW_ORDER := [World.COIN, World.WALL, World.TRAP, World.ZOMBIE, World.HERO]
## obj_score: draw_set_colour(16777088) = BGR $FFFF80 -> RGB (128, 255, 255)
const SCORE_COLOR := Color8(128, 255, 255)
const STEP_SEC := 1.0 / World.Room0.SPEED

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


func _read_input() -> Dictionary:
	return {
		"up": Input.is_key_pressed(KEY_UP),
		"down": Input.is_key_pressed(KEY_DOWN),
		"left": Input.is_key_pressed(KEY_LEFT),
		"right": Input.is_key_pressed(KEY_RIGHT),
		"mouse_down": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"mouse": _room.get_local_mouse_position(),
	}


func _draw_room() -> void:
	_room.draw_rect(Rect2(0, 0, World.W, World.H), Color.BLACK)  # room colour 0
	for kind in DRAW_ORDER:
		var tex: Texture2D = TEX[kind]
		var o: Vector2 = ORIGIN[kind]
		for i in world.of_kind(kind):
			var sc := Vector2(i.sx, i.sy)
			var pos := Vector2(i.x, i.y) - o * sc
			_room.draw_texture_rect(tex, Rect2(pos.round(), tex.get_size() * sc), false)
	for s in world.of_kind(World.SCORE):
		var font := get_theme_default_font()
		var fs := 16
		_room.draw_string(font, Vector2(s.x, s.y + font.get_ascent(fs)),
				"score: " + str(world.score), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SCORE_COLOR)
