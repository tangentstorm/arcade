extends Control
## tankgame Direct — Godot 4 port of the Opal/Phaser tankgame prototype.
## 800x600 stage, letterboxed. R regenerates terrain. Esc is left for PauseOverlay.

const Logic := preload("res://games/tankgame/direct/tank_logic.gd")
const BG := preload("res://games/tankgame/direct/sprites/background.png")
const TILES := preload("res://games/tankgame/direct/sprites/msquares.png")
const TANKS := [preload("res://games/tankgame/direct/sprites/tank0.png"),
	preload("res://games/tankgame/direct/sprites/tank1.png")]
const GUNS := [preload("res://games/tankgame/direct/sprites/gun0.png"),
	preload("res://games/tankgame/direct/sprites/gun1.png")]

var state: Logic = Logic.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_ALL
	state.generate()
	resized.connect(queue_redraw)
	call_deferred("grab_focus")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		state.generate()
		queue_redraw()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var s := minf(size.x / Logic.STAGE_W, size.y / Logic.STAGE_H)
	if s <= 0.0:
		return
	var o := (size - Vector2(Logic.STAGE_W, Logic.STAGE_H) * s) * 0.5
	draw_set_transform(o, 0.0, Vector2(s, s))
	draw_texture(BG, Vector2.ZERO)
	for x in Logic.MW:
		for y in Logic.MH:
			var t := state.msquare(x, y)
			if t == 0:
				continue
			draw_texture_rect_region(TILES,
				Rect2(x * Logic.TW, y * Logic.TH, Logic.TW, Logic.TH),
				Rect2(t * Logic.TW, 0, Logic.TW, Logic.TH))
	for i in Logic.NTANKS:  # guns first, then tanks (original add order)
		draw_texture(GUNS[i], Logic.gun_pos(i))
		draw_texture(TANKS[i], Logic.tank_pos(i))
	draw_set_transform(Vector2.ZERO)
