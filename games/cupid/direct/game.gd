extends Control
## Cupid: Direct edition.
## A port of tangentstorm/cupid (ActionScript 3 + Flixel v1, 2010).
## The simulation lives in cupid_logic.gd and steps at Flixel's fixed 90 Hz.
## This script draws the 656x350 Flash stage scaled to fit with nearest filtering,
## feeds in the mouse, and plays the rain loop. Esc goes to the PauseOverlay
## autoload, and pausing the tree stops the simulation.

const Logic := preload("res://games/cupid/direct/cupid_logic.gd")
const DIR := "res://games/cupid/direct/"
const CUPID := preload(DIR + "sprites/cupid.png")
const ARROW := preload(DIR + "sprites/arrow.png")
const PEOPLE := preload(DIR + "sprites/pixel-people-standins-gray.png")
const BUBBLE := preload(DIR + "sprites/bubble.png")
const SYMBOLS := preload(DIR + "sprites/symbols.png")
const GOOD_ICON := preload(DIR + "sprites/HEART-Symbol-animated.png")
const BAD_ICON := preload(DIR + "sprites/heart-breaking.png")
const RAIN := preload(DIR + "sprites/heavy-rain.png")
const CURSOR := preload(DIR + "sprites/crosshair-heart-1.png")
const TITLE_IMG := preload(DIR + "sprites/title.png")
const BG := [
	preload(DIR + "sprites/bg-00.png"), preload(DIR + "sprites/bg-01.png"),
	preload(DIR + "sprites/bg-02.png"), preload(DIR + "sprites/bg-03.png"),
	preload(DIR + "sprites/bg-04.png"),
]
const RAIN_LOOP := preload(DIR + "audio/rain.mp3")

## Person mask: a tinted copy blended in "screen" mode over the sprite.
const PERSON_HIT_TINT := Color8(0xFF, 0xCC, 0xCC)

const W := Logic.STAGE_W
const H := Logic.STAGE_H

var world: Logic = Logic.new(Logic.TITLE)
var _acc := 0.0
var _s := 1.0
var _people_hit: Texture2D
var _click := false
var _start := false
var _next := false
var _rain: AudioStreamPlayer

@onready var _room: Control = %Room
@onready var _hud: Control = %Hud


func _ready() -> void:
	_room.size = Vector2(W, H)
	_room.draw.connect(_draw_room)
	_hud.draw.connect(_draw_hud)
	resized.connect(_fit_room)
	_fit_room()
	_people_hit = _make_hit_texture(PEOPLE)
	var loop: AudioStreamMP3 = RAIN_LOOP.duplicate()
	loop.loop = true
	_rain = AudioStreamPlayer.new()
	_rain.stream = loop
	add_child(_rain)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	# The heart crosshair replaces the OS cursor only while the game is live,
	# so the PauseOverlay buttons stay clickable.
	if what == NOTIFICATION_PAUSED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_UNPAUSED:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## mask.color = PERSON_HIT_TINT; mask.blend = "screen" over the same pixels:
## out = 1 - (1 - src*tint) * (1 - src), keeping the sprite's alpha.
func _make_hit_texture(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var t := Color(c.r * PERSON_HIT_TINT.r, c.g * PERSON_HIT_TINT.g, c.b * PERSON_HIT_TINT.b)
			img.set_pixel(x, y, Color(
					1.0 - (1.0 - t.r) * (1.0 - c.r),
					1.0 - (1.0 - t.g) * (1.0 - c.g),
					1.0 - (1.0 - t.b) * (1.0 - c.b), c.a))
	return ImageTexture.create_from_image(img)


func _fit_room() -> void:
	_s = minf(size.x / W, size.y / H)
	if _s <= 0.0:
		return
	_room.scale = Vector2(_s, _s)
	_room.position = ((size - Vector2(W, H) * _s) * 0.5).floor()
	_hud.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_start = true
		elif event.keycode == KEY_N:
			_next = true


func _stage_mouse() -> Vector2:
	return (get_local_mouse_position() - _room.position) / _s


func _process(delta: float) -> void:
	_acc = minf(_acc + delta, 0.25)
	var stepped := false
	var m := _stage_mouse()
	while _acc >= Logic.DT:
		_acc -= Logic.DT
		world.step({"stage_x": m.x, "stage_y": m.y, "click": _click, "start": _start, "next_level": _next})
		_click = false
		_start = false
		_next = false
		stepped = true
	_update_audio()
	if stepped:
		_room.queue_redraw()
		_hud.queue_redraw()


func _update_audio() -> void:
	var gain: float = world.rain_gain()
	if world.state == Logic.TITLE:
		if _rain.playing:
			_rain.stop()
		return
	if not _rain.playing:
		_rain.play()  # music.rain()
	_rain.volume_db = linear_to_db(gain) if gain > 0.001 else -80.0


# --- drawing ------------------------------------------------------------------
func _scr(x: float, y: float, sf := 1.0) -> Vector2:
	return Vector2(floor(x) + floor(world.scroll_x * sf), floor(y) + floor(world.scroll_y * sf))


## Draw frame `frame` of a horizontal strip, mirrored when facing left
## (loadGraphic(..., Reverse=true) flips the whole frame).
func _frame(tex: Texture2D, frame: int, fw: int, fh: int, at: Vector2, flip := false) -> void:
	var src := Rect2(frame * fw, 0, fw, fh)
	var dst := Rect2(at, Vector2(fw, fh))
	if flip:
		dst = Rect2(at + Vector2(fw, 0), Vector2(-fw, fh))
	_room.draw_texture_rect_region(tex, dst, src)


func _draw_room() -> void:
	_room.draw_rect(Rect2(0, 0, W, H), Color.BLACK)
	if world.state == Logic.TITLE:
		# MenuState: the title image (centered here; see PORT.md)
		_room.draw_texture(TITLE_IMG, ((Vector2(W, H) - TITLE_IMG.get_size()) * 0.5).floor())
		_draw_cursor()
		return

	# addBgLayer x5, each a single sprite at (0,0) with its own scrollFactor.x
	for i in BG.size():
		_room.draw_texture(BG[i], Vector2(floor(world.scroll_x * Logic.BG_SCROLL[i]), 0))

	# lyrSprites: cupid, then each person with bubble, symbol, mask; then the arrow
	_frame(CUPID, world.cupid_anim.caf, Logic.CUPID_W, Logic.CUPID_H, _scr(world.cx, world.cy), not world.c_right)
	for p in world.people:
		if not p.exists:
			continue
		var at := _scr(p.x, p.y)
		if at.x > W or at.x + Logic.PERSON_W < 0:
			continue
		_frame(PEOPLE, p.image, Logic.PERSON_W, Logic.PERSON_H, at, not p.right)
		if p.marked:
			_room.draw_texture(BUBBLE, _scr(p.mark_x, p.y - Logic.BUBBLE_HEIGHT))
			_frame(SYMBOLS, p.symbol, 30, 30,
					_scr(p.mark_x + Logic.SYMBOL_OFFSET_X, p.y - Logic.BUBBLE_HEIGHT + Logic.SYMBOL_OFFSET_Y))
			_frame(_people_hit, p.image, Logic.PERSON_W, Logic.PERSON_H, _scr(p.mark_x, p.y), not p.mark_right)
	if world.arrow_exists:
		_room.draw_texture(ARROW, _scr(world.ax, world.ay))

	# lyrRain: particles share the emitter's scrollFactor (0.33)
	var rx: float = floor(world.scroll_x * Logic.RAIN_SCROLL_FACTOR)
	var rs := Logic.RAIN_SIZE
	for i in world.rain_alive.size():
		if world.rain_alive[i] == 0:
			continue
		var px: float = floor(world.rain_x[i]) + rx
		if px > W or px + rs < 0:
			continue
		_room.draw_texture_rect_region(RAIN, Rect2(px, floor(world.rain_y[i]), rs, rs),
				Rect2(world.rain_frame[i] * rs, 0, rs, rs))

	# lyrHUD (scrollFactor.x = 0): match icons at the stage centre
	var ip := Vector2((W - Logic.MATCH_ICON_SIZE) / 2, (H - Logic.MATCH_ICON_SIZE) / 2)
	for icon in [world.good_icon, world.bad_icon]:
		if icon.visible:
			_frame(GOOD_ICON if icon.good else BAD_ICON, icon.anim.caf, 40, 40, ip)
	_draw_cursor()


func _draw_cursor() -> void:
	# FlxG.showCursor(HeartCursor): the image's top-left sits on the mouse
	var m := _stage_mouse()
	_room.draw_texture(CURSOR, m.floor())


# --- HUD text (screen resolution, positioned in stage coordinates) -----------
func _text(label: String, p: Vector2, fs: float, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := get_theme_default_font()
	var px := int(round(fs * _s))
	var at := _room.position + p * _s
	var wdt := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		at.x -= wdt * 0.5
	at.y += font.get_ascent(px)
	_hud.draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(2, int(_s)), Color(0, 0, 0, 0.7))
	_hud.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, c)


func _draw_hud() -> void:
	match world.state:
		Logic.TITLE:
			var y := (H + TITLE_IMG.get_size().y) * 0.5 + 6
			_text("Click (or Space) to start", Vector2(W * 0.5, y), 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			_text("Steer Cupid with the mouse, click to drop an arrow. Shoot two people with the same symbol to make a couple.",
					Vector2(W * 0.5, y + 14), 8, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
			_text("Esc: pause", Vector2(W * 0.5, y + 26), 8, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
		Logic.WON:
			# FlxText(STAGE_WIDTH/2, STAGE_HEIGHT/2, STAGE_WIDTH, "YOU WON!"): 8px white, left-aligned
			_text("YOU WON!", Vector2(W / 2, H / 2), 8, Color.WHITE)
			_text("Press Space to play again", Vector2(W * 0.5, H / 2 + 40), 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
