extends Control
## Tentraminos — Direct edition. Faithful port of tangentstorm/tentraminos (LD27).
## Logic: tentraminos_logic.gd. This script draws the SVG-equivalent board and maps keys.
## Esc is handled globally by the PauseOverlay autoload (pausing the tree stops our tick).

const Logic := preload("res://games/tentraminos/direct/tentraminos_logic.gd")

const CELL := 32.0           # original cellsize (SVG px)
const BOARD_SCALE := 2.0     # original board was 320x320 SVG; scale up for 720p
const GRID_Y := 36.0         # <g transform="translate(0,36)">
const BLACK := Color.BLACK

## keyCode -> command, exactly the original `dvorak` keymap + arrow keys.
const KEYMAP := {
	# dvorak layout
	KEY_C: "^", KEY_H: "<", KEY_N: ">", KEY_O: "(", KEY_P: "p", KEY_T: "v", KEY_U: ")",
	# documented as "o/j" in the original help text; keyCode 85 there is actually U
	KEY_J: ")",
	# for use with arrows
	KEY_X: ")", KEY_Z: "(",
	# wasd (+ k/l rotate)
	KEY_W: "^", KEY_A: "<", KEY_S: "v", KEY_D: ">", KEY_K: "(", KEY_L: ")",
	KEY_LEFT: "<", KEY_UP: "^", KEY_RIGHT: ">", KEY_DOWN: "v",
}

var game = Logic.new()
var _acc_ms := 0.0
var _cursor_px := Vector2.ZERO  # animated cursor position (SVG px, grid space)
var _cursor_tween: Tween

@onready var _board: Control = %Board
@onready var _clock: Label = %ClockValue
@onready var _score: Label = %ScoreValue
@onready var _status: Label = %Status


func _ready() -> void:
	_board.custom_minimum_size = Vector2(9 * CELL + 2, GRID_Y + 9 * CELL + 2) * BOARD_SCALE
	_board.draw.connect(_draw_board)
	_cursor_px = _cursor_target()
	_refresh_labels()


func _process(delta: float) -> void:
	_acc_ms = minf(_acc_ms + delta * 1000.0, 1000.0)
	while _acc_ms >= Logic.TICK_MS:
		_acc_ms -= Logic.TICK_MS
		game.tick(Logic.TICK_MS)
	_refresh_labels()
	_board.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	if game.next == Logic.THEEND:
		if k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_R, KEY_SPACE]:
			restart()
			get_viewport().set_input_as_handled()
		return
	if not KEYMAP.has(k.keycode):
		return
	var c: String = KEYMAP[k.keycode]
	if c == "p" and k.echo:
		return
	game.code(c)
	_move_cursor()
	get_viewport().set_input_as_handled()


func restart() -> void:
	game.new_game()
	_acc_ms = 0.0
	_move_cursor()


func _cursor_target() -> Vector2:
	return Vector2(game.cursor_x, game.cursor_y) * CELL + Vector2(4, 4)


## cursor.transition().duration(50)
func _move_cursor() -> void:
	if _cursor_tween:
		_cursor_tween.kill()
	_cursor_tween = create_tween()
	_cursor_tween.tween_property(self, "_cursor_px", _cursor_target(), 0.05) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _refresh_labels() -> void:
	_clock.text = str(floori(game.shown_clock / float(Logic.SECONDS)))
	_score.text = str(game.shown_score)
	if game.next == Logic.THEEND:
		_status.text = "game over — press Enter to play again"
	elif game.paused:
		_status.text = "paused (p)"
	else:
		_status.text = ""


# -- drawing (mirrors the SVG in tentraminos.html) ---------------------------

## SVG-style rect: stroke centred on the edge.
func _svg_rect(r: Rect2, fill: Color, stroke: Color, width: float = 1.0, filled := true) -> void:
	var h := width / 2.0
	if filled:
		_board.draw_rect(r.grow(h), stroke)
		_board.draw_rect(r.grow(-h), fill)
	else:
		var o := r.grow(h)
		_board.draw_rect(Rect2(o.position, Vector2(o.size.x, width)), stroke)
		_board.draw_rect(Rect2(o.position + Vector2(0, o.size.y - width), Vector2(o.size.x, width)), stroke)
		_board.draw_rect(Rect2(o.position, Vector2(width, o.size.y)), stroke)
		_board.draw_rect(Rect2(o.position + Vector2(o.size.x - width, 0), Vector2(width, o.size.y)), stroke)


func _draw_board() -> void:
	var colors: Array[Color] = Logic.COLORS
	_board.draw_set_transform(Vector2.ONE * BOARD_SCALE, 0.0, Vector2(BOARD_SCALE, BOARD_SCALE))
	# hold row
	_svg_rect(Rect2(0, 0, 9 * CELL, CELL), colors[0], BLACK)
	for i in Logic.GW:
		_svg_rect(Rect2(CELL * i, 0, CELL, CELL), colors[game.shown_hold[i]], BLACK)
	# grid
	_board.draw_set_transform(Vector2(0, GRID_Y) * BOARD_SCALE + Vector2.ONE * BOARD_SCALE,
			0.0, Vector2(BOARD_SCALE, BOARD_SCALE))
	_svg_rect(Rect2(0, 0, 9 * CELL, 9 * CELL), colors[0], BLACK)
	for i in Logic.NUMCELLS:
		var m: int = game.shown_matrix[i]
		if m == 0:
			continue  # opacity 0
		var stroke := colors[m - 9] if m >= 9 else BLACK
		_svg_rect(Rect2(CELL * (i % 9), CELL * (i / 9), CELL, CELL), colors[m], stroke)
	# cursor: 56x56, stroke-width 8, no fill
	_svg_rect(Rect2(_cursor_px, Vector2(CELL * 2 - 8, CELL * 2 - 8)), BLACK, BLACK, 8.0, false)
