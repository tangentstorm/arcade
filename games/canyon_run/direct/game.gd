extends Control
## Canyon Run Direct: draws CanyonLogic on a 240×320 portrait stage at 2× (480×640),
## centred in the 1280×720 base viewport (letterbox scale mode).
## Esc is handled globally by the PauseOverlay autoload (pause / Back to Arcade).

const Logic := preload("res://games/canyon_run/direct/canyon_logic.gd")
const SCALE := 2.0
const STAGE_POS := Vector2(400, 40)   # (1280 - 480) / 2, (720 - 640) / 2

const COL_BG := Color(0.05, 0.05, 0.09)
const COL_ROCK := Color(0.42, 0.27, 0.16)
const COL_ROCK_EDGE := Color(0.62, 0.42, 0.24)
const COL_WATER := Color(0.12, 0.30, 0.55)
const COL_CRAFT := Color(0.95, 0.92, 0.55)
const COL_ENEMY := Color(0.85, 0.25, 0.25)
const COL_BULLET := Color(1, 1, 0.8)

var logic = Logic.new(Time.get_ticks_usec())
var steer_override := 0.0   # tests can drive the craft without input events


func _ready() -> void:
	%BackButton.pressed.connect(GameRegistry.return_to_arcade)


func _process(delta: float) -> void:
	var steer := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		steer -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		steer += 1.0
	if steer_override != 0.0:
		steer = steer_override
	steer = clamp(steer, -1.0, 1.0)
	var throttle := Input.get_axis("ui_down", "ui_up")
	if Input.is_physical_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		throttle -= 1.0
	if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_Z):
		if not logic.restart_if_ready():
			logic.fire()
	logic.update(delta, steer, clamp(throttle, -1.0, 1.0))
	_update_hud()
	queue_redraw()


func _update_hud() -> void:
	%Score.text = "SCORE %d\nBEST %d\nSPEED %d" % [logic.score, max(logic.best, logic.score), int(logic.speed)]
	match logic.state:
		Logic.State.READY:
			%Message.text = "CANYON RUN\n\nsteer / throttle / Space to start"
		Logic.State.CRASHED:
			%Message.text = "CRASHED\n\nscore %d\n\nSpace to fly again" % logic.score \
				if logic.crash_timer >= Logic.CRASH_HOLD else "CRASHED"
		_:
			%Message.text = ""


func _s(p: Vector2) -> Vector2:
	return STAGE_POS + p * SCALE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	var stage := Rect2(STAGE_POS, Vector2(Logic.STAGE_W, Logic.STAGE_H) * SCALE)
	draw_rect(stage, COL_WATER)
	# Canyon walls, one strip per row (ROW_H stage px).
	var y := 0.0
	while y < Logic.STAGE_H:
		var w: Vector2 = logic.walls_at(logic.world_y(y + Logic.ROW_H))
		var h := Logic.ROW_H * SCALE
		draw_rect(Rect2(_s(Vector2(0, y)), Vector2(w.x * SCALE, h)), COL_ROCK)
		draw_rect(Rect2(_s(Vector2(w.y, y)), Vector2((Logic.STAGE_W - w.y) * SCALE, h)), COL_ROCK)
		draw_rect(Rect2(_s(Vector2(w.x - 2, y)), Vector2(2 * SCALE, h)), COL_ROCK_EDGE)
		draw_rect(Rect2(_s(Vector2(w.y, y)), Vector2(2 * SCALE, h)), COL_ROCK_EDGE)
		y += Logic.ROW_H
	for e in logic.enemies:
		var c: Vector2 = Vector2(e.pos.x, logic.screen_y(e.pos.y))
		draw_rect(Rect2(_s(c - Logic.ENEMY_HALF), Logic.ENEMY_HALF * 2 * SCALE), COL_ENEMY)
	for b in logic.bullets:
		var c := Vector2(b.x, logic.screen_y(b.y))
		draw_rect(Rect2(_s(c - Vector2(1, 3)), Vector2(2, 6) * SCALE), COL_BULLET)
	# Mask anything spawned just off-stage (above / below the letterboxed stage).
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, STAGE_POS.y)), COL_BG)
	draw_rect(Rect2(Vector2(0, stage.end.y), Vector2(size.x, size.y - stage.end.y)), COL_BG)
	# Craft: a simple arrowhead.
	var p := Vector2(logic.player_x, Logic.PLAYER_Y)
	var hx: float = Logic.PLAYER_HALF.x
	var hy: float = Logic.PLAYER_HALF.y
	var col := COL_CRAFT if logic.state != Logic.State.CRASHED else COL_ENEMY
	draw_colored_polygon(PackedVector2Array([
		_s(p + Vector2(0, -hy)), _s(p + Vector2(hx, hy)),
		_s(p + Vector2(0, hy * 0.4)), _s(p + Vector2(-hx, hy))]), col)
