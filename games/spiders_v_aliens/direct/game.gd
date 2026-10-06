extends Control
## Spiders v. Aliens: Direct edition.
## A port of tangentstorm/spiders-v-aliens (AS3 + Flixel 2.55, Ludum Dare 21 "Escape", 2011).
## The simulation lives in sva_logic.gd and steps at Flixel's fixed 60 Hz. This script draws the
## 640x480 Flash stage scaled to fit with nearest filtering, feeds in the keyboard, and plays the
## music. Esc goes to the PauseOverlay autoload, and pausing the tree stops the simulation.

const Logic := preload("res://games/spiders_v_aliens/direct/sva_logic.gd")
const DIR := "res://games/spiders_v_aliens/direct/"
const FONT_FILE := preload(DIR + "fonts/nokiafc22.ttf")
const MUSIC := preload(DIR + "audio/sva-music.mp3")
const OPENING1_IMG := preload(DIR + "sprites/opening-01.png")
const OPENING2_IMG := preload(DIR + "sprites/opening-02.png")
const TILESETS := {
	"Outside": preload(DIR + "sprites/startiles.png"),
	"Environment": preload(DIR + "sprites/environment.png"),
	"Decorations": preload(DIR + "sprites/railings.png"),
	"GeistWall": preload(DIR + "sprites/geistwall.png"),
}
const SPRITES := {
	"Hero": preload(DIR + "sprites/hero.png"),
	"Geist": preload(DIR + "sprites/geist.png"),
	"Spider": preload(DIR + "sprites/spider.png"),
	"Alien": preload(DIR + "sprites/alien.png"),
	"Box": preload(DIR + "sprites/box.png"),
	"Key": preload(DIR + "sprites/key.png"),
	"Heart": preload(DIR + "sprites/heart.png"),
	"Exit": preload(DIR + "sprites/exit.png"),
	"HeroShip": preload(DIR + "sprites/ship.png"),
	"KeyBox": preload(DIR + "sprites/keybox.png"),
	"Portal": preload(DIR + "sprites/portal.png"),
	"Cannon": preload(DIR + "sprites/cannon.png"),
	"SwitchBox": preload(DIR + "sprites/switchbox.png"),
	"Bullet": preload(DIR + "sprites/bullet.png"),
	"Grabber": preload(DIR + "sprites/grabbers.png"),
}

const W := Logic.STAGE_W
const H := Logic.STAGE_H
const GREY := Color8(0xcc, 0xcc, 0xcc)

## Flixel 2.55 FlxG._volume defaults to 0.5; playMusic(SndMusic) uses volume 1.0.
const MUSIC_VOLUME := 0.5

## Physical keys Flixel's PlayState / menus poll (FlxG.keys uses Flash keyCodes).
const KEYMAP := {
	"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
	"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D,
	"comma": KEY_COMMA, "o": KEY_O, "e": KEY_E,
	"g": KEY_G, "space": KEY_SPACE,
}

var world: Logic = Logic.new(Logic.MENU)
var _acc := 0.0
var _s := 1.0
var _just := {}
var _font: FontFile
var _music: AudioStreamPlayer

@onready var _room: Control = %Room


func _ready() -> void:
	_room.size = Vector2(W, H)
	_room.draw.connect(_draw_room)
	resized.connect(_fit_room)
	_fit_room()
	_font = FONT_FILE.duplicate()
	_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_font.hinting = TextServer.HINTING_NONE
	_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var loop: AudioStreamMP3 = MUSIC.duplicate()
	loop.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = loop
	_music.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(_music)


func _exit_tree() -> void:
	world.dispose()


func _fit_room() -> void:
	_s = minf(size.x / W, size.y / H)
	if _s <= 0.0:
		return
	_room.scale = Vector2(_s, _s)
	_room.position = ((size - Vector2(W, H) * _s) * 0.5).floor()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for k in KEYMAP:
			if event.keycode == KEYMAP[k]:
				_just[k] = true


func _held() -> Dictionary:
	var held := {}
	for k in KEYMAP:
		held[k] = Input.is_key_pressed(KEYMAP[k])
	return held


func _process(delta: float) -> void:
	_acc = minf(_acc + delta, 0.25)
	var stepped := false
	while _acc >= Logic.DT:
		_acc -= Logic.DT
		var held := _held()
		for k in _just:
			held[k] = true  # a tap shorter than one frame still counts as held once
		world.step({"held": held, "just": _just})
		_just = {}
		stepped = true
		if world.music_start:
			_music.play()  # FlxG.playMusic restarts the loop from the top
	if stepped:
		_room.queue_redraw()


# --- drawing ------------------------------------------------------------------
func _base() -> Transform2D:
	return Transform2D(0.0, Vector2(world.shake_x, world.shake_y))


func _cam(o: Logic.Obj, px: float, py: float) -> Vector2:
	return Vector2(floor(px - floor(world.scroll_x * o.sf) - o.off_x),
			floor(py - floor(world.scroll_y * o.sf) - o.off_y))


func _draw_obj(o: Logic.Obj) -> void:
	if not o.exists or not o.visible:
		return
	var tex: Texture2D = SPRITES[o.kind]
	var fw := 16.0
	var fh := 20.0
	if o.kind == "HeroShip":
		fw = 80.0
		fh = 50.0
	var at := _cam(o, o.x, o.y)
	if at.x > W or at.y > H or at.x + o.w * 2 < -fw or at.y + o.h * 2 < -fh:
		return
	var src := Rect2(o.frame * fw, 0, fw, fh)
	if o.angle == 0.0 and o.scale_x == 1.0 and o.scale_y == 1.0:
		_room.draw_texture_rect_region(tex, Rect2(at, Vector2(fw, fh)), src)
		return
	# FlxSprite complex draw: translate(-origin), scale, rotate, translate(point + origin)
	var origin := Vector2(fw, fh) * 0.5
	var xf := Transform2D(deg_to_rad(o.angle), Vector2(o.scale_x, o.scale_y), 0.0, at + origin)
	_room.draw_set_transform_matrix(_base() * xf)
	_room.draw_texture_rect_region(tex, Rect2(-origin, Vector2(fw, fh)), src)
	_room.draw_set_transform_matrix(_base())


func _draw_tilemap(t: Logic.Obj) -> void:
	if not t.visible:
		return
	var tex: Texture2D = TILESETS[t.tm_name]
	var cols := int(tex.get_width()) / t.tw
	var ox: float = t.x - floor(world.scroll_x * t.sf)
	var oy: float = t.y - floor(world.scroll_y * t.sf)
	var c0 := maxi(0, int(floor(-ox / t.tw)))
	var c1 := mini(t.wt - 1, int(floor((W - ox) / t.tw)))
	var r0 := maxi(0, int(floor(-oy / t.th)))
	var r1 := mini(t.ht - 1, int(floor((H - oy) / t.th)))
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var v: int = t.data[r * t.wt + c]
			if v < t.draw_idx:
				continue
			var src := Rect2((v % cols) * t.tw, (v / cols) * t.th, t.tw, t.th)
			_room.draw_texture_rect_region(tex, Rect2(floor(ox) + c * t.tw, floor(oy) + r * t.th, t.tw, t.th), src)


## FlxText: Flash TextField with a 2px gutter, word-wrapped to `width`.
func _text(x: float, y: float, width: float, size: int, label: String, col := Color.WHITE,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if label.is_empty():
		return
	var at := Vector2(x + 2, y + 2 + _font.get_ascent(size))
	_room.draw_multiline_string(_font, at, label, align, width - 4, size, -1, col)


func _center(y: float, size: int, label: String, col := GREY) -> void:
	_text(0, y, W, size, label, col, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_room() -> void:
	_room.draw_set_transform_matrix(Transform2D.IDENTITY)
	_room.draw_rect(Rect2(0, 0, W, H), Color.BLACK)
	_room.draw_set_transform_matrix(_base())
	var cy := H / 2.0
	match world.state:
		Logic.MENU:
			_center(cy - 70, 12, "Ernie Goldsmile, Attorney at Law")
			_center(cy - 50, 12, "in:")
			_center(cy - 30, 16, "Spiders v. Aliens", Color.WHITE)
			_center(cy + 10, 12, "Use arrow keys to move,")
			_center(cy + 30, 12, "[WASD] or [,AOE] grab and drag objects")
			_center(H - 20, 14, "press space to begin.", Color.WHITE)
		Logic.OPENING1, Logic.OPENING2:
			var img: Texture2D = OPENING1_IMG if world.state == Logic.OPENING1 else OPENING2_IMG
			_room.draw_texture(img, Vector2((640 - 270) / 2, 64))
			_text(32, H - 120, W, 12, world.opening_type.text, GREY)
			_center(H - 20, 14, "press space to continue.", Color.WHITE)
		Logic.DEATH:
			_center(H / 2.0 - 10, 16, "GAME OVER", Color.WHITE)
			_center(H - 20, 14, "press space to restart.", Color.WHITE)
		Logic.WIN:
			_center(H / 2.0 - 10, 16, "Congratulations! You Escaped!", Color.WHITE)
			_center(H - 20, 14, "press space to restart.", Color.WHITE)
		Logic.PLAY:
			_draw_play()
	_room.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_play() -> void:
	for o in world.master_layer:
		if o.is_tilemap():
			_draw_tilemap(o)
		else:
			_draw_obj(o)
	for g in world.grabber_list:
		_draw_obj(g)
	# HUD: 64px 0xee000000 strip, hearts, TeleType narration
	var hy := H - Logic.HUD_HEIGHT
	_room.draw_rect(Rect2(0, hy, W, Logic.HUD_HEIGHT), Color8(0, 0, 0, 0xee))
	for i in world.hud_hearts.size():
		var hh = world.hud_hearts[i]
		hh.frame = world.heart_frame(i)
		_draw_obj(hh)
	_text(Logic.HUD_PADDING, hy + Logic.HUD_PADDING * 2, W * 0.75, 14, world.hud_text.text)
	# objects add()ed after create() (cannon bullets) draw over the HUD, as in the original
	for o in world.dispensed:
		_draw_obj(o)
