extends Node2D
## mineswpr (Enhanced). A modern Minesweeper presentation of the Direct port of
## tangentstorm's mineswpr.org (Retro Forth 11, 2013) on a 1280x720 letterbox
## stage: beveled tiles, classic hint colors, flag and reveal animations, a
## ripple flood, a mine counter and timer, and win / lose juice.
##
## No rules are copied. The board is the Direct mineswpr_logic.gd and every
## move (mouse, keyboard, or a typed command) goes through the Direct mswp'
## shell as the same `x y ?` / `x y +` / `x y -` command Direct runs, so the
## board evolves exactly as it does in Direct (cardinal-only flood, flags kept
## through floods, no first-click safety, 16x16 with 24 mines).
## Esc is handled globally by the PauseOverlay autoload.

const Logic := preload("res://games/mineswpr/direct/mineswpr_logic.gd")
const Shell := preload("res://games/mineswpr/direct/mswp_shell.gd")
const MONO := preload("res://games/mineswpr/direct/assets/NotoSansMono-Regular.ttf")

const STAGE := Vector2(1280, 720)
const CELL := 38.0
const BOARD_POS := Vector2(336, 82)
const BOARD_SIZE := Vector2(Logic.W, Logic.H) * CELL
const MAX_INPUT := 40

enum { PLAY, LOST, WON }

const BG_TOP := Color(0.06, 0.07, 0.14)
const BG_BOTTOM := Color(0.10, 0.06, 0.18)
const PANEL_BG := Color(0.10, 0.11, 0.22, 0.88)
const FRAME := Color(0.40, 0.55, 1.0)
const INK := Color(0.92, 0.94, 1.0)
const MUTED := Color(0.60, 0.65, 0.85)
const GOLD := Color(1.0, 0.84, 0.32)
const TILE := Color(0.27, 0.34, 0.58)
const TILE_ALT := Color(0.25, 0.32, 0.55)
const TILE_HOVER := Color(0.36, 0.45, 0.74)
const OPEN := Color(0.10, 0.11, 0.20)
const OPEN_ALT := Color(0.11, 0.12, 0.22)
const FLAG_RED := Color(1.0, 0.30, 0.32)
const MINE_INK := Color(0.08, 0.08, 0.12)
const BOOM := Color(0.85, 0.12, 0.18)
const WIN_GREEN := Color(0.35, 0.95, 0.55)
## Classic hint colors, brightened for a dark board.
const HINT_COLORS := [Color.WHITE,
	Color(0.40, 0.70, 1.00), Color(0.40, 0.90, 0.45), Color(1.00, 0.42, 0.42),
	Color(0.75, 0.55, 1.00), Color(1.00, 0.65, 0.25), Color(0.30, 0.90, 0.90),
	Color(0.95, 0.95, 0.95), Color(0.70, 0.72, 0.80)]

var game = Logic.new()
var shell = Shell.new(game)
var state := PLAY
var save_path := "user://mineswpr_enhanced.cfg"
var best_time := -1.0
var elapsed := 0.0
var running := false
var cursor := Vector2i(7, 7)          ## keyboard cursor (board point)
var hover := Vector2i(-1, -1)
var input := ""
var last_cmd := ""
var last_error := ""

var _time := 0.0
var _reveal_at := {}                  ## cell -> time its reveal animation starts
var _flag_at := {}                    ## cell -> time the flag popped in
var _ping := {}                       ## cell -> time of the last command on it (Direct's |m)
var _mine_at := {}                    ## cell -> time a mine is shown (loss / win cascade)
var _boom_cell := -1
var _particles: Array[Dictionary] = []   ## {pos, vel, life, max, color, size, grav}
var _floaters: Array[Dictionary] = []    ## {pos, life, text, color}
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _press := Vector2i(-1, -1)

var _ui: CanvasLayer
var _cards := {}
var _mines_label: Label
var _time_label: Label
var _best_label: Label
var _progress: ProgressBar
var _progress_label: Label
var _console_label: Label
var _stack_label: Label
var _result_title: Label
var _result_sub: Label
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	best_time = _load_best()
	shell.quit_requested.connect(_quit)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_hud()


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	scale = Vector2(s, s)
	position = (size - STAGE * s) * 0.5
	if _ui:
		_ui.transform = transform


func _process(delta: float) -> void:
	_time += delta
	if running:
		elapsed += delta
	_animate(delta)
	_refresh_hud()
	queue_redraw()


# ---- moves (all through the Direct shell) --------------------------------------

## Run one classic command line exactly as Direct does, then diff the board to
## drive the presentation.
func run(line: String) -> void:
	var before := _snapshot()
	var was_over: bool = game.game_over
	var was_clear: bool = game.cleared()
	shell.eval_line(line)
	last_error = shell.last_error
	if line.strip_edges() != "":
		last_cmd = line.strip_edges()
	var origin: int = game.active_cell
	game.active_cell = -1            # Direct's draw forgets it after one frame, too
	_after_move(before, was_over, was_clear, origin)


## Mouse / keyboard move on a board point: the same command Direct's click runs.
func click_cell(x: int, y: int, button: int) -> void:
	if state != PLAY or not Logic.inbounds(x, y):
		return
	var op := "?"
	if button == MOUSE_BUTTON_RIGHT:
		op = "-" if game.has(Logic.cell(x, y), Logic.FLAG) else "+"
	elif button != MOUSE_BUTTON_LEFT:
		return
	cursor = Vector2i(x, y)
	run("%X %X %s" % [x, y, op])


func new_game() -> void:
	run("r")


func _snapshot() -> PackedInt32Array:
	return game.grid.duplicate()


func _after_move(before: PackedInt32Array, was_over: bool, was_clear: bool, origin: int) -> void:
	var cov := 1 << Logic.COVER
	var flg := 1 << Logic.FLAG
	if _is_new_board(before):
		_reset_view()
		return
	if origin >= 0:
		_ping[origin] = _time
	var o: Vector2i = Logic.c2xy(origin) if origin >= 0 else cursor
	var opened := 0
	for c in Logic.W * Logic.H:
		var was: int = before[c]
		var now: int = game.grid[c]
		if was & cov and not now & cov:
			var p: Vector2i = Logic.c2xy(c)
			_reveal_at[c] = _time + minf(Vector2(p - o).length() * 0.028, 0.6)
			opened += 1
		if not was & flg and now & flg:
			_flag_at[c] = _time
			_burst(_cell_center(c), FLAG_RED, 8, 120.0, 3.0, 0.4)
		elif was & flg and not now & flg and now & cov:
			_burst(_cell_center(c), MUTED, 6, 80.0, 2.5, 0.3)
	if opened > 0:
		running = running or not game.game_over
		if opened >= 8:
			_float_text(_cell_center(origin if origin >= 0 else Logic.cell(o.x, o.y)), "+%d" % opened, INK)
	if game.game_over and not was_over:
		_lose(origin)
	elif not game.game_over and game.cleared() and not was_clear:
		_win()


## `r` / `play` ran game-new: the mines moved, or a finished board was reset.
func _is_new_board(before: PackedInt32Array) -> bool:
	if game.covered_count() != Logic.W * Logic.H or game.game_over:
		return false
	if state != PLAY:
		return true
	for c in Logic.W * Logic.H:
		if (before[c] ^ game.grid[c]) & (1 << Logic.MINE):
			return true
	return false


func _reset_view() -> void:
	state = PLAY
	running = false
	elapsed = 0.0
	_reveal_at.clear()
	_flag_at.clear()
	_mine_at.clear()
	_ping.clear()
	_boom_cell = -1
	_flash = 0.4
	_flash_color = FRAME
	_show_card("")


func _lose(origin: int) -> void:
	state = LOST
	running = false
	_boom_cell = origin
	var o: Vector2i = Logic.c2xy(origin) if origin >= 0 else cursor
	for c in Logic.W * Logic.H:
		if game.has(c, Logic.MINE):
			var p: Vector2i = Logic.c2xy(c)
			_mine_at[c] = _time + (0.0 if c == origin else 0.15 + Vector2(p - o).length() * 0.05)
	var at := _cell_center(origin) if origin >= 0 else BOARD_POS + BOARD_SIZE * 0.5
	_burst(at, Color(1.0, 0.55, 0.2), 40, 420.0, 5.0, 0.9)
	_burst(at, BOOM, 24, 260.0, 4.0, 0.7)
	_shake = 1.0
	_flash = 0.6
	_flash_color = BOOM
	_result_title.text = "BOOM!"
	_result_title.add_theme_color_override("font_color", FLAG_RED)
	_result_sub.text = "You hit a mine at %X %X after %s." % [o.x, o.y, _fmt_time(elapsed)]
	_show_card("result")


func _win() -> void:
	state = WON
	running = false
	var new_best := best_time < 0.0 or elapsed < best_time
	if new_best:
		best_time = elapsed
		_save_best(best_time)
	var i := 0
	for c in Logic.W * Logic.H:
		if game.has(c, Logic.MINE):
			_mine_at[c] = _time + 0.05 * i
			i += 1
	for k in 6:
		var p := BOARD_POS + Vector2(randf() * BOARD_SIZE.x, randf() * BOARD_SIZE.y * 0.5)
		_burst(p, [GOLD, WIN_GREEN, FRAME, FLAG_RED][k % 4], 18, 300.0, 4.0, 1.2, 380.0)
	_flash = 0.5
	_flash_color = WIN_GREEN
	_result_title.text = "ALL CLEAR!"
	_result_title.add_theme_color_override("font_color", WIN_GREEN)
	_result_sub.text = "Swept in %s%s" % [_fmt_time(elapsed), "  -  new best!" if new_best else ""]
	_show_card("result")


func _quit() -> void:
	GameRegistry.return_to_arcade.call_deferred()


# ---- input ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(_board_point(event.position))
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var pt := _board_point(event.position)
		if event.pressed:
			_press = pt
		elif pt.x >= 0 and pt == _press:
			click_cell(pt.x, pt.y, event.button_index)
		if not event.pressed:
			_press = Vector2i(-1, -1)
		if pt.x >= 0:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		var pt := _board_point(event.position)
		if pt.x >= 0:
			click_cell(pt.x, pt.y, MOUSE_BUTTON_LEFT)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		_on_key(event)


func _on_key(e: InputEventKey) -> void:
	match e.keycode:
		KEY_ESCAPE:
			return                                  # PauseOverlay
		KEY_ENTER, KEY_KP_ENTER:
			if input.strip_edges() == "":
				if state == PLAY:
					click_cell(cursor.x, cursor.y, MOUSE_BUTTON_RIGHT if e.shift_pressed else MOUSE_BUTTON_LEFT)
				else:
					new_game()
			else:
				var line := input
				input = ""
				run(line)
		KEY_TAB:
			click_cell(cursor.x, cursor.y, MOUSE_BUTTON_RIGHT)
		KEY_BACKSPACE:
			input = input.left(-1)
		KEY_F2:
			new_game()
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			var d := {KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0),
				KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1)}[e.keycode] as Vector2i
			cursor = Vector2i(clampi(cursor.x + d.x, 0, Logic.W - 1), clampi(cursor.y + d.y, 0, Logic.H - 1))
		_:
			if e.ctrl_pressed or e.alt_pressed or e.meta_pressed:
				return
			if e.unicode < 32 or e.unicode > 126:
				return
			if input.length() < MAX_INPUT:
				input += char(e.unicode)
	get_viewport().set_input_as_handled()


func _set_hover(pt: Vector2i) -> void:
	hover = pt
	if pt.x >= 0:
		cursor = pt


## Viewport position -> board point, or (-1, -1) off the board.
func _board_point(viewport_pos: Vector2) -> Vector2i:
	var p := (viewport_pos - position) / scale - BOARD_POS
	if p.x < 0 or p.y < 0 or p.x >= BOARD_SIZE.x or p.y >= BOARD_SIZE.y:
		return Vector2i(-1, -1)
	return Vector2i(int(p.x / CELL), int(p.y / CELL))


func _cell_center(c: int) -> Vector2:
	var p: Vector2i = Logic.c2xy(c)
	return BOARD_POS + (Vector2(p) + Vector2(0.5, 0.5)) * CELL


# ---- juice ------------------------------------------------------------------------

func _burst(pos: Vector2, color: Color, n: int, speed: float, size: float, life: float,
		grav := 0.0) -> void:
	for i in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.3, 1.0)
		_particles.append({"pos": pos, "vel": v, "life": life, "max": life,
			"color": color, "size": size * randf_range(0.6, 1.2), "grav": grav})


func _float_text(pos: Vector2, text: String, color: Color) -> void:
	pos = pos.clamp(BOARD_POS + Vector2(40, 30), BOARD_POS + BOARD_SIZE - Vector2(40, 10))
	_floaters.append({"pos": pos, "life": 0.9, "text": text, "color": color})


func _animate(delta: float) -> void:
	for p in _particles:
		p.life -= delta
		p.vel *= 0.94
		p.vel.y += p.grav * delta
		p.pos += p.vel * delta
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos.y -= 40.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	_shake = maxf(0.0, _shake - delta * 2.2)
	_flash = maxf(0.0, _flash - delta * 1.5)


# ---- drawing ----------------------------------------------------------------------

func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(STAGE.x, 0), STAGE, Vector2(0, STAGE.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	var sh := Vector2.ZERO
	if _shake > 0.0:
		sh = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _shake * _shake
	draw_set_transform(sh)
	var frame := Rect2(BOARD_POS - Vector2(10, 10), BOARD_SIZE + Vector2(20, 20))
	draw_rect(frame.grow(6), Color(FRAME, 0.10 + 0.05 * sin(_time * 2.0)))
	draw_rect(frame, Color(0.05, 0.06, 0.12))
	draw_rect(frame, Color(FRAME, 0.7), false, 2.0)
	_draw_axes()
	for c in Logic.W * Logic.H:
		_draw_cell(c)
	_draw_cursor()
	for p in _particles:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
		draw_circle(p.pos, p.size * (0.4 + 0.6 * a), Color(p.color, a))
	for f in _floaters:
		var a: float = clampf(f.life / 0.9, 0.0, 1.0)
		draw_string(_font, f.pos + Vector2(-40, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 80, 24, Color(f.color, a))
	draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, STAGE), Color(_flash_color, _flash * 0.25))


## Hex coordinate rulers: the numbers you'd type at the `ok` prompt.
func _draw_axes() -> void:
	for i in Logic.W:
		var hi := (i == cursor.x)
		var col := GOLD if hi else Color(MUTED, 0.7)
		draw_string(MONO, BOARD_POS + Vector2(i * CELL, -14), "%X" % i, HORIZONTAL_ALIGNMENT_CENTER, CELL, 16, col)
	for j in Logic.H:
		var hi := (j == cursor.y)
		var col := GOLD if hi else Color(MUTED, 0.7)
		draw_string(MONO, BOARD_POS + Vector2(-34, j * CELL + CELL * 0.5 + 6), "%X" % j, HORIZONTAL_ALIGNMENT_CENTER, 20, 16, col)


func _draw_cell(c: int) -> void:
	var p: Vector2i = Logic.c2xy(c)
	var r := Rect2(BOARD_POS + Vector2(p) * CELL, Vector2(CELL, CELL)).grow(-1.5)
	var covered: bool = game.has(c, Logic.COVER)
	var flagged: bool = game.has(c, Logic.FLAG)
	var mine: bool = game.has(c, Logic.MINE)
	var alt := (p.x + p.y) % 2 == 1
	var t_rev: float = clampf((_time - float(_reveal_at.get(c, -10.0))) / 0.18, 0.0, 1.0)
	var opened := not covered and t_rev > 0.0
	if covered or not opened:
		_draw_tile(r, p, alt)
	else:
		draw_rect(r, OPEN_ALT if alt else OPEN)
		if t_rev < 1.0:  # the tile shrinks away
			_draw_tile(r.grow(-r.size.x * 0.5 * t_rev), p, alt, 1.0 - t_rev)
		var n: int = game.armed_neighbor_count(c)
		if n > 0 and not mine:
			var s := lerpf(0.6, 1.0, t_rev)
			var fs := int(26 * s)
			draw_string(MONO, r.position + Vector2(0, r.size.y * 0.5 + fs * 0.36), str(n),
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, HINT_COLORS[n])
	# mines (shown on loss / win)
	if _mine_at.has(c) and _time >= float(_mine_at[c]):
		var ta := clampf((_time - float(_mine_at[c])) / 0.2, 0.0, 1.0)
		if state == WON:
			_draw_flag(r, ta, WIN_GREEN)
		else:
			if c == _boom_cell:
				draw_rect(r, BOOM)
			elif not flagged:
				draw_rect(r, Color(0.30, 0.10, 0.16, ta))
			if not flagged or c == _boom_cell:
				_draw_mine(r, ta)
	# flags (kept through floods, like Direct's `!` on an uncovered cell)
	if flagged and not (state == WON and mine):
		var tf := clampf((_time - float(_flag_at.get(c, -10.0))) / 0.18, 0.0, 1.0)
		_draw_flag(r, _back_out(tf), FLAG_RED if covered else Color(FLAG_RED, 0.55))
		if state == LOST and not mine:
			var k := r.grow(-9)
			draw_line(k.position, k.end, INK, 3.0)
			draw_line(Vector2(k.end.x, k.position.y), Vector2(k.position.x, k.end.y), INK, 3.0)
	# last-command ping (Direct highlights the active cell for one draw)
	if _ping.has(c):
		var tp := (_time - float(_ping[c])) / 0.5
		if tp < 1.0:
			draw_rect(r.grow(2 + 6 * tp), Color(1.0, 0.35, 1.0, 1.0 - tp), false, 2.0)


func _draw_tile(r: Rect2, p: Vector2i, alt: bool, alpha := 1.0) -> void:
	var base := TILE_ALT if alt else TILE
	if p == hover and state == PLAY:
		base = TILE_HOVER
	if p == _press and state == PLAY:
		base = base.darkened(0.2)
	draw_rect(r, Color(base, alpha))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(1, 1, 1, 0.16 * alpha))
	draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Color(1, 1, 1, 0.10 * alpha))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), Color(0, 0, 0, 0.28 * alpha))
	draw_rect(Rect2(r.position + Vector2(r.size.x - 3, 0), Vector2(3, r.size.y)), Color(0, 0, 0, 0.20 * alpha))


func _draw_flag(r: Rect2, t: float, color: Color) -> void:
	if t <= 0.0:
		return
	var c := r.get_center()
	var s := 0.5 + 0.5 * t
	var base := c + Vector2(-2, 11) * s
	draw_line(base, c + Vector2(-2, -11) * s, Color(0.9, 0.9, 0.95), 2.5)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-1, -11) * s, c + Vector2(11, -5) * s,
		c + Vector2(-1, 1) * s]), color)
	draw_line(c + Vector2(-8, 11) * s, c + Vector2(5, 11) * s, Color(0.9, 0.9, 0.95), 2.5)


func _draw_mine(r: Rect2, t: float) -> void:
	var c := r.get_center()
	var rad := 8.0 * (0.4 + 0.6 * t)
	for i in 8:
		var a := i * TAU / 8.0
		draw_line(c + Vector2(cos(a), sin(a)) * rad * 0.5, c + Vector2(cos(a), sin(a)) * rad * 1.45, MINE_INK, 2.5)
	draw_circle(c, rad, MINE_INK)
	draw_circle(c + Vector2(-2.5, -2.5) * t, 2.2 * t, Color(1, 1, 1, 0.8))


func _draw_cursor() -> void:
	if state != PLAY or not Logic.inbounds(cursor.x, cursor.y):
		return
	var r := Rect2(BOARD_POS + Vector2(cursor) * CELL, Vector2(CELL, CELL)).grow(1)
	draw_rect(r, Color(GOLD, 0.65 + 0.35 * sin(_time * 6.0)), false, 2.5)


static func _back_out(t: float) -> float:
	var s := 1.70158
	t -= 1.0
	return t * t * ((s + 1.0) * t + s) + 1.0


# ---- HUD ----------------------------------------------------------------------------

func uncovered_safe() -> int:
	var n := 0
	for c in Logic.W * Logic.H:
		if not game.has(c, Logic.MINE) and not game.has(c, Logic.COVER):
			n += 1
	return n


func safe_total() -> int:
	var n := 0
	for c in Logic.W * Logic.H:
		if not game.has(c, Logic.MINE):
			n += 1
	return n


func mines_left() -> int:
	return Logic.MINE_COUNT - game.flag_count


func _refresh_hud() -> void:
	if _mines_label == null:
		return
	_mines_label.text = "%02d" % (0 if state == WON else mines_left())
	_time_label.text = _fmt_time(elapsed)
	_best_label.text = _fmt_time(best_time) if best_time >= 0.0 else "--"
	var safe := uncovered_safe()
	var total := safe_total()
	_progress.max_value = total
	_progress.value = safe
	_progress_label.text = "%d / %d safe cells" % [safe, total]
	var caret := "_" if fmod(_time, 1.0) < 0.5 else " "
	_console_label.text = "ok " + input + caret
	var info := "last: " + (last_cmd if last_cmd != "" else "-")
	if last_error != "":
		info += "    " + last_error
	_stack_label.text = info + "\nstack: " + shell.stack_text()


static func _fmt_time(t: float) -> String:
	if t < 0.0:
		return "--"
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


func _show_card(key: String) -> void:
	for k in _cards:
		_cards[k].visible = (k == key)


func _load_best() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return -1.0
	return float(cfg.get_value("best", "time", -1.0))


func _save_best(value: float) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("best", "time", value)
	cfg.save(save_path)


func _label(text: String, size: int, color := INK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color, font_size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	for st in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = color.lightened(0.15) if st == "hover" else color.darkened(0.15) if st == "pressed" else color
		s.border_color = color.lightened(0.45)
		s.set_border_width_all(2)
		s.set_corner_radius_all(10)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 6
		s.content_margin_bottom = 8
		b.add_theme_stylebox_override(st, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	return b


func _panel(root: Control, rect: Rect2) -> Control:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.border_color = Color(FRAME, 0.45)
	s.set_border_width_all(2)
	s.set_corner_radius_all(16)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(p, rect)
	root.add_child(p)
	return p


func _place(c: Control, rect: Rect2) -> Control:
	c.position = rect.position
	c.size = rect.size
	return c


func _add(parent: Control, c: Control, rect: Rect2) -> Control:
	_place(c, rect)
	parent.add_child(c)
	return c


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(root, Rect2(Vector2.ZERO, STAGE))
	_ui.add_child(root)

	var title := _label("MINESWPR", 34, FRAME.lightened(0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(root, title, Rect2(0, 6, STAGE.x, 44))

	var back := _button("Back to Arcade", Color(0.25, 0.32, 0.65), 18)
	back.position = Vector2(14, 12)
	back.pressed.connect(GameRegistry.return_to_arcade)
	root.add_child(back)

	# left panel: counters
	var lp := _panel(root, Rect2(28, 82, 280, 608))
	_add(lp, _label("MINES LEFT", 18, MUTED), Rect2(24, 18, 232, 26))
	_mines_label = _add(lp, _label("24", 64, FLAG_RED, MONO), Rect2(24, 40, 232, 80))
	_add(lp, _label("TIME", 18, MUTED), Rect2(24, 136, 232, 26))
	_time_label = _add(lp, _label("0:00", 48, INK, MONO), Rect2(24, 158, 232, 64))
	_add(lp, _label("BEST", 18, MUTED), Rect2(24, 236, 232, 26))
	_best_label = _add(lp, _label("--", 30, GOLD, MONO), Rect2(24, 260, 232, 44))
	_add(lp, _label("PROGRESS", 18, MUTED), Rect2(24, 322, 232, 26))
	_progress = ProgressBar.new()
	_progress.max_value = Logic.W * Logic.H - Logic.MINE_COUNT
	_progress.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.12)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = WIN_GREEN.darkened(0.15)
	fill.set_corner_radius_all(6)
	_progress.add_theme_stylebox_override("background", bg)
	_progress.add_theme_stylebox_override("fill", fill)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(lp, _progress, Rect2(24, 352, 232, 16))
	_progress_label = _add(lp, _label("", 16, MUTED), Rect2(24, 374, 232, 24))
	var ng := _button("New Game", Color(0.20, 0.52, 0.42), 22)
	ng.pressed.connect(new_game)
	_add(lp, ng, Rect2(40, 420, 200, 46))
	_add(lp, _label("16 x 16 board, 24 mines.\nFlood opens through\nn / w / e / s only,\nas in the 2013 original.",
		15, MUTED), Rect2(24, 490, 232, 100))

	# right panel: controls + the classic `ok` prompt
	var rp := _panel(root, Rect2(972, 82, 280, 608))
	_add(rp, _label("CONTROLS", 18, MUTED), Rect2(24, 18, 232, 26))
	_add(rp, _label("Left click   reveal\nRight click  flag / unflag\nArrows       move cursor\nEnter        reveal at cursor\nTab          flag at cursor\nF2           new game\nEsc          pause",
		15, INK, MONO), Rect2(24, 46, 240, 170))
	_add(rp, _label("CLASSIC COMMANDS (hex)", 18, MUTED), Rect2(24, 236, 232, 26))
	_add(rp, _label("x y ?  prod   (e.g. 5 C ?)\nx y +  flag   x y -  unflag\nr  new game    q  quit",
		14, MUTED, MONO), Rect2(24, 264, 240, 70))
	var con := _panel(rp, Rect2(16, 350, 248, 120))
	(con.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.02, 0.03, 0.06, 0.95)
	_console_label = _add(con, _label("ok _", 20, Color(0.55, 1.0, 0.6), MONO), Rect2(12, 10, 230, 30))
	_stack_label = _add(con, _label("", 14, MUTED, MONO), Rect2(12, 48, 230, 64))
	_add(rp, _label("Type a command, then Enter.\nEvery click runs the same\ncommand the original used.",
		15, MUTED), Rect2(24, 490, 232, 80))

	# result card (win / lose), over the board
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	_add(root, holder, Rect2(Vector2.ZERO, STAGE))
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(holder, center, Rect2(BOARD_POS, BOARD_SIZE))
	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.09, 0.20, 0.94)
	s.border_color = FRAME
	s.set_border_width_all(2)
	s.set_corner_radius_all(20)
	s.shadow_color = Color(FRAME, 0.25)
	s.shadow_size = 18
	s.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", s)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	_result_title = _label("", 52, INK)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result_title)
	_result_sub = _label("", 20, MUTED)
	_result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result_sub)
	var again := _button("Play Again", Color(0.20, 0.52, 0.42), 24)
	again.pressed.connect(new_game)
	v.add_child(again)
	var hint := _label("Enter / F2 for a new board", 15, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_cards["result"] = holder
