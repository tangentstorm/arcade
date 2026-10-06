extends Control
## typing.deck Direct — Godot 4 falling-words typer.
## Esc is left for PauseOverlay; do not handle ui_cancel here.

const Logic := preload("res://games/typing/direct/typing_logic.gd")
const Gfx := preload("res://games/typing/direct/typing_gfx.gd")
const Words := preload("res://games/typing/direct/words.gd")

const W := Logic.STAGE_W
const H := Logic.STAGE_H

var state: Logic = Logic.new()
var _s := 1.0
var _ox := 0.0
var _oy := 0.0
var _font: Font
var _click_rects: Array = []  ## {rect, id, arg}
var _last_key := ""
var _last_key_ttl := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_font = ThemeDB.fallback_font
	resized.connect(_fit)
	_fit()
	call_deferred("grab_focus")


func _fit() -> void:
	var sz := size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	_s = minf(sz.x / float(W), sz.y / float(H))
	_ox = (sz.x - W * _s) * 0.5
	_oy = (sz.y - H * _s) * 0.5
	queue_redraw()


func _process(delta: float) -> void:
	# Capture/gallery may set size deferred; re-fit when it becomes valid.
	if size.x > 0.0 and size.y > 0.0 and (_s <= 0.0 or absf(size.x - (W * _s + 2.0 * _ox)) > 1.0):
		_fit()
	state.tick(delta)
	if _last_key_ttl > 0.0:
		_last_key_ttl = maxf(0.0, _last_key_ttl - delta)
		if _last_key_ttl <= 0.0:
			_last_key = ""
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := _to_stage(event.position)
		for item in _click_rects:
			if (item["rect"] as Rect2).has_point(p):
				_activate(str(item["id"]), item.get("arg", null))
				accept_event()
				return
	elif event is InputEventKey and event.pressed and not event.echo:
		# Never consume Esc / ui_cancel — PauseOverlay owns it.
		if event.is_action("ui_cancel") or event.keycode == KEY_ESCAPE:
			return
		if state.mode == Logic.Mode.HOME:
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				state.start_play()
				accept_event()
				return
		elif state.mode == Logic.Mode.PLAY:
			if event.keycode == KEY_P and event.ctrl_pressed == false and event.alt_pressed == false:
				# Optional: bare P does not pause — use on-screen button.
				pass
			var ch := char(event.unicode) if event.unicode > 0 else ""
			if ch == "" and event.keycode >= KEY_A and event.keycode <= KEY_Z:
				ch = char(event.keycode - KEY_A + 97)
			if ch != "":
				_last_key = ch.to_lower()
				_last_key_ttl = 0.25
				state.type_key(ch)
				accept_event()
		elif state.mode == Logic.Mode.WON:
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				state.go_home()
				accept_event()


func _to_stage(p: Vector2) -> Vector2:
	return Vector2((p.x - _ox) / _s, (p.y - _oy) / _s)


func _activate(id: String, arg: Variant) -> void:
	match id:
		"play":
			state.start_play()
		"home":
			state.go_home()
		"pause":
			state.toggle_pause()
		"word_list":
			state.set_word_list(str(arg))
		"layout":
			state.set_layout(str(arg))
	queue_redraw()


func _draw() -> void:
	_click_rects.clear()
	# Letterbox bars
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	draw_set_transform(Vector2(_ox, _oy), 0.0, Vector2(_s, _s))
	# Stage
	draw_rect(Rect2(0, 0, W, H), Gfx.STAGE)
	if state.mode == Logic.Mode.HOME:
		_draw_home()
	else:
		_draw_game()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_home() -> void:
	_text("typing.deck", Vector2(W * 0.5, 28), 18, Gfx.INK, true)
	_text("words fall", Vector2(W * 0.5, 70), 14, Gfx.INK, true)
	_text("from the sky", Vector2(W * 0.5, 88), 14, Gfx.INK, true)
	_text("type them fast", Vector2(W * 0.5, 112), 14, Gfx.INK, true)
	_text("or you will die", Vector2(W * 0.5, 130), 14, Gfx.INK, true)
	_text("- mavis b", Vector2(W * 0.5, 152), 12, Gfx.GRAY, true)

	_text("word list:", Vector2(120, 190), 12, Gfx.INK, false)
	var y := 188.0
	for name in Words.WORD_LIST_NAMES:
		var sel: bool = name == state.word_list_name
		var r := Rect2(210, y, 160, 18)
		draw_rect(r, Gfx.PANEL if sel else Gfx.KEY_BG)
		_text(name, Vector2(r.position.x + 6, r.position.y + 3), 11, Gfx.WHT, false)
		_click_rects.append({"rect": r, "id": "word_list", "arg": name})
		y += 20.0

	_text("keyboard:", Vector2(120, 280), 12, Gfx.INK, false)
	var kx := 210.0
	for name in Words.LAYOUT_NAMES:
		var sel2: bool = name == state.layout_name
		var r2 := Rect2(kx, 278, 70, 18)
		draw_rect(r2, Gfx.PANEL if sel2 else Gfx.KEY_BG)
		_text(name, Vector2(r2.position.x + 6, r2.position.y + 3), 11, Gfx.WHT, false)
		_click_rects.append({"rect": r2, "id": "layout", "arg": name})
		kx += 76.0

	var play := Rect2(366, 144, 80, 24)
	draw_rect(play, Gfx.GRN)
	_text("Play", Vector2(play.position.x + 22, play.position.y + 4), 14, Gfx.WHT, false)
	_click_rects.append({"rect": play, "id": "play", "arg": null})
	_text("Enter = Play", Vector2(366, 176), 10, Gfx.GRAY, false)


func _draw_game() -> void:
	# Flash overlay
	if state.flash_kind != "" and state.flash_ttl > 0.0:
		var fc: Dictionary = Gfx.flash_colors(state.flash_kind)
		draw_rect(Rect2(0, 0, W, H), fc["bg"])
		_text(state.flash_msg, Vector2(W * 0.5, H * 0.35), 22, fc["fg"], true)

	# Welcome box
	if state.show_welcome and state.mode == Logic.Mode.PLAY:
		draw_rect(Rect2(169, 25, 175, 85), Color(1, 1, 1, 0.15))
		_text("type 15 falling words", Vector2(W * 0.5, 36), 11, Gfx.INK, true)
		_text("before they reach the bottom", Vector2(W * 0.5, 52), 10, Gfx.INK, true)
		_text("speed increases every 5 words", Vector2(W * 0.5, 70), 10, Gfx.INK, true)
		_text('type "go" to begin', Vector2(W * 0.5, 90), 11, Gfx.CUR, true)

	# Falling / current word
	if state.mode == Logic.Mode.PLAY or state.mode == Logic.Mode.WON:
		_draw_progress_word(Vector2(state.word_x, state.word_y), state.word, state.progress)

	# HUD
	_text("speed: %d" % state.speed, Vector2(420, 25), 11, Gfx.INK, false)
	_text("score: %d" % state.score, Vector2(420, 46), 11, Gfx.INK, false)
	var pr := Rect2(420, 67, 70, 16)
	draw_rect(pr, Gfx.PANEL if state.paused else Gfx.KEY_BG)
	_text("pause" if not state.paused else "PAUSED", Vector2(pr.position.x + 8, pr.position.y + 2), 10, Gfx.WHT, false)
	_click_rects.append({"rect": pr, "id": "pause", "arg": null})

	# Keyboard
	_draw_keyboard(Vector2(169, 253))

	if state.mode == Logic.Mode.WON:
		var again := Rect2(W * 0.5 - 50, 200, 100, 24)
		draw_rect(again, Gfx.BLU)
		_text("Home", Vector2(again.position.x + 30, again.position.y + 4), 14, Gfx.WHT, false)
		_click_rects.append({"rect": again, "id": "home", "arg": null})


func _draw_progress_word(pos: Vector2, w: String, prog: int) -> void:
	var x := pos.x
	var fs := 16
	for i in w.length():
		var ch := w.substr(i, 1)
		var col := Gfx.INK
		if i < prog:
			col = Gfx.TYPED
		elif i == prog:
			col = Gfx.CUR
		_text(ch, Vector2(x, pos.y), fs, col, false)
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0


func _draw_keyboard(origin: Vector2) -> void:
	var rows: PackedStringArray = Words.layout_rows(state.layout_name)
	var cw := 15.0
	var y := origin.y
	for ri in rows.size():
		var row: String = rows[ri]
		var x := origin.x + float(ri) * (cw / 3.0)
		for j in row.length():
			var ch := row.substr(j, 1)
			if ch == ".":
				x += cw + 1.0
				continue
			if ch == "\n":
				continue
			var r := Rect2(x, y, cw, cw)
			var hl := ch == _last_key
			draw_rect(r, Gfx.KEY_HL if hl else Gfx.KEY_BG)
			_text(ch, Vector2(x + 4, y + 2), 10, Gfx.WHT if not hl else Gfx.BLK, false)
			x += cw + 1.0
		y += cw + 1.0


func _text(s: String, pos: Vector2, fs: int, col: Color, center: bool) -> void:
	var p := pos
	if center:
		var sz := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		p = Vector2(pos.x - sz.x * 0.5, pos.y)
	draw_string(_font, p + Vector2(0, fs), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
