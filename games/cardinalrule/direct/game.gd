extends Control
## cardinalrule Direct — Godot 4 port of tangentscraps/cardinalrule (LD25, 2012).
## Title = the flixel MenuState text; play = spritetest.pas (cardinal, arrows, gravity).
## 512x448 stage, letterboxed. Esc is left for PauseOverlay.

const Logic := preload("res://games/cardinalrule/direct/bird_logic.gd")
const HERO_TEX := preload("res://games/cardinalrule/direct/img/cardinal-r.png")
const PLAY_BG := Color("#003399")  ## {$BACKGROUND $003399}
const MENU_BG := Color.BLACK       ## CardinalRule.as backgroundColor

var playing := false
var bird: Logic = Logic.new()
var _acc := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_ALL
	resized.connect(queue_redraw)
	call_deferred("grab_focus")


func start() -> void:
	playing = true
	bird = Logic.new()
	_acc = 0.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not playing:
		var click: bool = event is InputEventMouseButton and event.pressed
		var enter: bool = event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		if click or enter:
			start()
			accept_event()
	elif event is InputEventKey and event.pressed \
			and event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		bird.key(event.keycode)  # echoes count, like Flash key repeat
		accept_event()


func _process(delta: float) -> void:
	if not playing:
		return
	_acc = minf(_acc + delta, 0.25)
	var tick := 1.0 / Logic.FPS
	while _acc >= tick:
		_acc -= tick
		bird.step()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var s := minf(size.x / Logic.STAGE_W, size.y / Logic.STAGE_H)
	if s <= 0.0:
		return
	var o := (size - Vector2(Logic.STAGE_W, Logic.STAGE_H) * s) * 0.5
	draw_set_transform(o, 0.0, Vector2(s, s))
	if playing:
		draw_rect(Rect2(0, 0, Logic.STAGE_W, Logic.STAGE_H), PLAY_BG)
		draw_texture_rect(HERO_TEX, Rect2(bird.pos.round(), Vector2(Logic.HERO, Logic.HERO)), false)
	else:
		# flixel 256x224 @ zoom 2: title at y=h/2-10 size 16, "click to play" at y=h-20.
		var f := get_theme_default_font()
		draw_rect(Rect2(0, 0, Logic.STAGE_W, Logic.STAGE_H), MENU_BG)
		draw_string(f, Vector2(0, 204 + 32), "CardinalRule", HORIZONTAL_ALIGNMENT_CENTER,
			Logic.STAGE_W, 32)
		draw_string(f, Vector2(156, 408 + 16), "click to play", HORIZONTAL_ALIGNMENT_CENTER,
			200, 16)
	draw_set_transform(Vector2.ZERO)
