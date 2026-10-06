extends Control
## Canyon Run Direct: draws CanyonLogic on a 240×320 portrait stage at 2× (480×640),
## centred in the 1280×720 base viewport (letterbox scale mode).
## Visuals: paper-cut topo port of Claude Design canyon-run.dc-script.js (see canyon_topo.gd).
## Esc is handled globally by the PauseOverlay autoload (pause / Back to Arcade).

const Logic := preload("res://games/canyon_run/direct/canyon_logic.gd")
const Topo := preload("res://games/canyon_run/direct/canyon_topo.gd")
const SCALE := 2.0
const STAGE_POS := Vector2(400, 40)   # (1280 - 480) / 2, (720 - 640) / 2

const COL_BG := Color(0.05, 0.05, 0.09)

var logic = Logic.new(Time.get_ticks_usec())
var topo = Topo.new()
var steer_override := 0.0   # tests can drive the craft without input events
var _bank := 0.0
var _font: Font


func _ready() -> void:
	%BackButton.pressed.connect(GameRegistry.return_to_arcade)
	_font = ThemeDB.fallback_font
	topo.reset(logic._seed)


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
	# Jet banks toward look-ahead (mock: plane leans into vx).
	_bank = move_toward(_bank, steer, delta * 4.0)
	topo.tick(delta)
	topo.sync_seed(logic._seed)
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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	topo.paint(self, logic, STAGE_POS, SCALE, _bank)
	# Mask anything spawned just off-stage (above / below the letterboxed stage).
	var stage := Rect2(STAGE_POS, Vector2(Logic.STAGE_W, Logic.STAGE_H) * SCALE)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, STAGE_POS.y)), COL_BG)
	draw_rect(Rect2(Vector2(0, stage.end.y), Vector2(size.x, size.y - stage.end.y)), COL_BG)
	draw_rect(Rect2(Vector2.ZERO, Vector2(STAGE_POS.x, size.y)), COL_BG)
	draw_rect(Rect2(Vector2(stage.end.x, 0), Vector2(size.x - stage.end.x, size.y)), COL_BG)
	if _font:
		topo.paint_badge(self, STAGE_POS, SCALE, _font)
