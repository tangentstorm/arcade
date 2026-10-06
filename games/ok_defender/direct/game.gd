extends Control
## oK Defender: Direct edition.
## A port of tangentstorm/ok-defender (oK/iKe, Ludum Dare 49, 2021).
## The simulation lives in ok_defender_logic.gd and steps at a fixed 30 Hz.
## This script draws the 320x200 iKe screen scaled to fit with nearest filtering,
## overlays the HUD at screen resolution, and feeds in keyboard input.
## Esc goes to the PauseOverlay autoload, and pausing the tree stops the tick.

const Logic := preload("res://games/ok_defender/direct/ok_defender_logic.gd")
const SHIP_STOP := preload("res://games/ok_defender/direct/sprites/ship-stop-r.png")
const SHIP_THRUST := preload("res://games/ok_defender/direct/sprites/ship-thrust-r.png")
const ALIEN := preload("res://games/ok_defender/direct/sprites/alien0.png")
const BEAM := preload("res://games/ok_defender/direct/sprites/beam.png")
const HUMAN := preload("res://games/ok_defender/direct/sprites/human.png")
const HUMAN_ASH := preload("res://games/ok_defender/direct/sprites/human-ash.png")
const STEP_SEC := 1.0 / Logic.FPS

## phaserR: ,3 4 7 8 in iKe's `arne` palette
const PHASER_COLORS := [Color("#be2633"), Color("#e06f8b"), Color("#eb8931"), Color("#f7e26b")]

# -- minimap (game.k "-- minimap --") --
const MAP_W := 120.0
const MAP_H := 15.0
const MAP_X := (Logic.W - MAP_W) / 2.0
const MAP_Y := 5.0
const MAP_BOX_STROKE := Color.WHITE
const MAP_CAM_STROKE := Color("#586e75")  # solarized@2

var world = Logic.new(Logic.TITLE)
var _acc := 0.0
var _s := 1.0

@onready var _room: Control = %Room
@onready var _hud: Control = %Hud


func _ready() -> void:
	_room.size = Vector2(Logic.W, Logic.H)
	_room.draw.connect(_draw_room)
	_hud.draw.connect(_draw_hud)
	resized.connect(_fit_room)
	_fit_room()


func _fit_room() -> void:
	_s = minf(size.x / Logic.W, size.y / Logic.H)
	if _s <= 0.0:
		return
	_room.scale = Vector2(_s, _s)
	_room.position = ((size - Vector2(Logic.W, Logic.H) * _s) * 0.5).floor()
	_hud.queue_redraw()


func _process(delta: float) -> void:
	_acc = minf(_acc + delta, 0.25)
	var stepped := false
	while _acc >= STEP_SEC:
		_acc -= STEP_SEC
		world.step(_read_input())
		stepped = true
	if stepped:
		_room.queue_redraw()
		_hud.queue_redraw()


## iKe `dir` (arrow keys) and `keys` (Space held = fire every tick).
func _read_input() -> Dictionary:
	var dx := int(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) \
			- int(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
	var dy := int(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) \
			- int(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W))
	return {"dx": dx, "dy": dy, "fire": Input.is_key_pressed(KEY_SPACE)}


# --- world-space rendering ----------------------------------------------------
## Screen x of a world x. Also returns the copy one world-width to the left so
## sprites that straddle the seam draw on both sides (game.k copyLeftSide).
func _sx(x: float) -> float:
	return fposmod(x - world.cam_x, world.world_w)


func _blit(tex: Texture2D, p: Vector2, flip := false) -> void:
	var sx := _sx(p.x)
	var sz := tex.get_size()
	for ox in [sx, sx - world.world_w]:
		if ox > Logic.W or ox + sz.x < 0:
			continue
		var at := Vector2(ox, p.y).round()
		if flip:
			_room.draw_set_transform(at + Vector2(sz.x, 0), 0.0, Vector2(-1, 1))
			_room.draw_texture(tex, Vector2.ZERO)
			_room.draw_set_transform(Vector2.ZERO)
		else:
			_room.draw_texture(tex, at)


func _rect(p: Vector2, sz: Vector2, c: Color) -> void:
	var sx := _sx(p.x)
	for ox in [sx, sx - world.world_w]:
		if ox > Logic.W or ox + sz.x < 0:
			continue
		_room.draw_rect(Rect2(Vector2(ox, p.y).round(), sz), c)


## falling::+|falling  -- the shared falling sprite turns 90 deg clockwise every 4 frames.
func _blit_falling(p: Vector2) -> void:
	var rot: int = world.fall_rot
	var offs := [Vector2(0, 0), Vector2(Logic.HUMAN_H, 0), Vector2(Logic.HUMAN_W, Logic.HUMAN_H), Vector2(0, Logic.HUMAN_W)]
	var sx := _sx(p.x)
	for ox in [sx, sx - world.world_w]:
		if ox > Logic.W or ox + Logic.HUMAN_H < 0:
			continue
		_room.draw_set_transform(Vector2(ox, p.y).round() + offs[rot], rot * PI * 0.5)
		_room.draw_texture(HUMAN, Vector2.ZERO)
		_room.draw_set_transform(Vector2.ZERO)


func _draw_room() -> void:
	_room.draw_rect(Rect2(0, 0, Logic.W, Logic.H), Color.BLACK)
	# sky: band@'!6
	for i in Logic.SKY.size():
		_room.draw_rect(Rect2(0, 30 * i, Logic.W, 30), Logic.SKY[i])

	# spriteLayer, in its original order
	for h in world.hu:
		_blit(HUMAN, h)
	for a in world.ash:
		_blit(HUMAN_ASH, a.pos)
	for h in world.fh:
		_blit_falling(h.pos)
	for a in world.al:
		if a.be:
			_blit(BEAM, Vector2(a.x, a.y) + Logic.BM_OFS)
	for a in world.al:
		_blit(ALIEN, Vector2(a.x, a.y))
	if world.state != Logic.GAMEOVER or not world.crashed or (world.f / 4) % 2 == 0:
		# $[abs[*dir]; s; stop[s]]  -- thrust sprite only while moving in x
		_blit(SHIP_THRUST if world.thrust else SHIP_STOP, world.sh, world.sh_d < 0)
	for p in world.ph:
		# always phaserR, even when flying left (tasks.org TODO left undone)
		for i in 4:
			_rect(p.pos + Vector2(i, 0), Vector2(1, 1), PHASER_COLORS[i])

	# r,:gnd  -- ground is drawn after (over) the sprites
	for i in world.gnd_w.size():
		_rect(Vector2(world.gnd_x[i], world.ground_top_i(i)), Vector2(world.gnd_w[i], world.gnd_h[i]), world.gnd_c[i])

	_draw_minimap()


func _draw_minimap() -> void:
	var sf: float = MAP_W / world.world_w
	_room.draw_rect(Rect2(MAP_X, MAP_Y, MAP_W, MAP_H), Color.BLACK)
	# [tasks.org] radar blips: humans, aliens, ship
	for h in world.hu:
		_blip(h.x, 1.0 + (h.y / Logic.H) * (MAP_H - 2), Color("#eb8931"), sf)
	for h in world.fh:
		_blip(h.pos.x, 1.0 + clampf(h.pos.y / Logic.H, 0, 1) * (MAP_H - 2), Color("#eb8931"), sf)
	for a in world.al:
		_blip(a.x + Logic.ALIEN_W * 0.5, 1.0 + clampf(a.y / Logic.H, 0, 1) * (MAP_H - 2), Color("#a3ce27"), sf)
	_blip(world.sh.x + Logic.SHIP_W * 0.5, 1.0 + (world.sh.y + 16) / Logic.H * (MAP_H - 2), Color.WHITE, sf)
	# camera box: split in two when the seam is in view (atSeam)
	var cw: float = sf * Logic.W
	var co: float = sf * world.cam_x
	var cy := MAP_Y + 1
	var ch := MAP_H - 2
	if world.cam_x + Logic.W > world.world_w:
		_room.draw_rect(Rect2(MAP_X, cy, cw - (MAP_W - co), ch), MAP_CAM_STROKE, false, 1.0)
		_room.draw_rect(Rect2(MAP_X + co, cy, MAP_W - co, ch), MAP_CAM_STROKE, false, 1.0)
	else:
		_room.draw_rect(Rect2(MAP_X + co, cy, cw, ch), MAP_CAM_STROKE, false, 1.0)
	_room.draw_rect(Rect2(MAP_X, MAP_Y, MAP_W, MAP_H), MAP_BOX_STROKE, false, 1.0)


func _blip(x: float, y: float, c: Color, sf: float) -> void:
	_room.draw_rect(Rect2(MAP_X + floor(fposmod(x, world.world_w) * sf), MAP_Y + floor(y), 1, 1), c)


# --- HUD (screen resolution, positioned in room coordinates) -----------------
func _text(label: String, p: Vector2, fs: float, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := get_theme_default_font()
	var px := int(round(fs * _s))
	var at := _room.position + p * _s
	var wdt := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		at.x -= wdt * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		at.x -= wdt
	_hud.draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(2, int(_s)), Color(0, 0, 0, 0.8))
	_hud.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, c)


func _draw_hud() -> void:
	var secs: int = world.f / Logic.FPS
	var dim := Color("#eee8d5")
	_text("TIME %d:%02d" % [secs / 60, secs % 60], Vector2(4, 11), 7, dim)
	_text("KILLS %d" % world.kills, Vector2(4, 19), 7, dim)
	_text("SAVED %d  LOST %d" % [world.saved, world.lost], Vector2(Logic.W - 4, 11), 7, dim, HORIZONTAL_ALIGNMENT_RIGHT)
	var carry := "CARRYING %d" % world.carried if world.carried else ""
	_text("HUMANS %d  %s" % [world.humans_left() - world.carried, carry], Vector2(Logic.W - 4, 19), 7, dim, HORIZONTAL_ALIGNMENT_RIGHT)
	var cx := Logic.W * 0.5
	match world.state:
		Logic.TITLE:
			_text("oK DEFENDER", Vector2(cx, 80), 24, Color("#f7e26b"), HORIZONTAL_ALIGNMENT_CENTER)
			_text("Ludum Dare 49  |  oK/iKe -> Godot", Vector2(cx, 96), 8, dim, HORIZONTAL_ALIGNMENT_CENTER)
			_text("Arrows / WASD: fly    Space (hold): phasers", Vector2(cx, 118), 8, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			_text("Shoot carriers, catch falling humans, fly low to set them down", Vector2(cx, 130), 7, dim, HORIZONTAL_ALIGNMENT_CENTER)
			_text("Press Space to start    Esc: pause", Vector2(cx, 150), 9, Color("#a3ce27"), HORIZONTAL_ALIGNMENT_CENTER)
		Logic.GAMEOVER:
			var why := "You crashed into an alien" if world.crashed else "Every human is gone"
			_text("GAME OVER", Vector2(cx, 80), 24, Color("#be2633"), HORIZONTAL_ALIGNMENT_CENTER)
			_text(why, Vector2(cx, 96), 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			_text("time %ds + kills %d + saved %d - lost %d" % [secs, world.kills, world.saved, world.lost],
					Vector2(cx, 114), 8, dim, HORIZONTAL_ALIGNMENT_CENTER)
			_text("SCORE %d" % world.score(), Vector2(cx, 132), 14, Color("#f7e26b"), HORIZONTAL_ALIGNMENT_CENTER)
			_text("Press Space to play again", Vector2(cx, 150), 9, Color("#a3ce27"), HORIZONTAL_ALIGNMENT_CENTER)
