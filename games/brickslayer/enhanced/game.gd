extends Node2D
## Brickslayer (Enhanced). A makeover of the Direct Breakout on a 1280x720
## letterbox stage: neon bricks colored by hits left, a glowing ball with a
## trail, a capsule paddle, hit flashes, shards and sparks, a score pop and a
## side HUD. The rules are brickslayer_enhanced_logic.gd, which extends the
## Direct logic, so the physics, scoring and lives match Direct.
## Esc is handled globally by the PauseOverlay autoload.

const Logic := preload("res://games/brickslayer/enhanced/brickslayer_enhanced_logic.gd")
const STAGE := Vector2(1280, 720)
const FS := 2.0                                   ## field scale (400x300 -> 800x600)
const FIELD_POS := Vector2(240, 100)              ## field top-left on the stage
const LAKE_Y := 280.0                             ## Direct lake top (logical px)
const SAVE_PATH := "user://brickslayer_enhanced.cfg"

const BG_TOP := Color(0.07, 0.06, 0.16)
const BG_BOTTOM := Color(0.13, 0.05, 0.20)
const FIELD_BG := Color(0.04, 0.05, 0.11)
const GRID := Color(0.35, 0.45, 1.0, 0.06)
const FRAME := Color(0.45, 0.55, 1.0)
const PANEL_BG := Color(0.10, 0.10, 0.22, 0.85)
const INK := Color(0.92, 0.94, 1.0)
const MUTED := Color(0.62, 0.66, 0.85)
const GOLD := Color(1.0, 0.84, 0.32)
const WATER := Color(0.16, 0.42, 0.95, 0.78)
const WATER_LIGHT := Color(0.55, 0.80, 1.0, 0.9)
const PADDLE := Color(0.86, 0.90, 1.0)
const PADDLE_ACCENT := Color(0.30, 0.85, 1.0)
const BALL := Color(1.0, 0.98, 0.92)
const BALL_GLOW := Color(1.0, 0.85, 0.45)
## Hits left -> color (Direct used gray shades 5 dark .. 1 white).
const SHADE_COLORS := {
	5: Color(1.00, 0.33, 0.48), 4: Color(1.00, 0.60, 0.25), 3: Color(1.00, 0.85, 0.25),
	2: Color(0.42, 0.88, 0.52), 1: Color(0.32, 0.80, 1.00),
}

var logic: Logic
var _acc_ms := 0.0
var _prev_ball := Vector2.ZERO
var _prev_paddle := 0.0
var _trail: Array[Vector2] = []
var _particles: Array[Dictionary] = []          ## {pos, vel, life, max, color, size, grav}
var _floaters: Array[Dictionary] = []           ## {pos, life, text}
var _brick_flash := {}                          ## brick index -> 0..1
var _shake := 0.0
var _paddle_squash := 0.0
var _lake_flash := 0.0
var _time := 0.0
var _held_left := false
var _held_right := false
var _brick_style := StyleBoxFlat.new()
var _paddle_style := StyleBoxFlat.new()
var _panel_style := StyleBoxFlat.new()
var _font: Font

var _ui: CanvasLayer
var _score_label: Label
var _level_label: Label
var _best_label: Label
var _bricks_label: Label
var _serve_hint: Label
var _cards := {}                                ## screen -> Control
var _clear_label: Label
var _over_score: Label
var _over_best: Label
var _over_level: Label
var _new_best: Label
var _retry_hint: Label
var _title_best: Label
var _score_tween: Tween
var _shown_score := -1


func _ready() -> void:
	logic = Logic.new()
	logic.best = _load_best()
	_font = ThemeDB.fallback_font
	_brick_style.set_corner_radius_all(3)
	_brick_style.anti_aliasing = true
	_paddle_style.set_corner_radius_all(8)
	_paddle_style.bg_color = PADDLE
	_panel_style.bg_color = PANEL_BG
	_panel_style.border_color = Color(FRAME, 0.45)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(16)
	_build_ui()
	_snap_prev()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_on_screen(logic.screen)


func _exit_tree() -> void:
	if logic:
		logic.dispose()


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	scale = Vector2(s, s)
	position = (size - STAGE * s) * 0.5


func _snap_prev() -> void:
	_prev_ball = Vector2(logic.ball.x, logic.ball.y)
	_prev_paddle = logic.paddle.x


func _process(delta: float) -> void:
	_time += delta
	_acc_ms = minf(_acc_ms + delta * 1000.0, 250.0)
	while _acc_ms >= Logic.TICK_MS:
		_acc_ms -= Logic.TICK_MS
		step_tick()
	_drain()                                      # input-driven events (start, pause)
	_animate(delta)
	queue_redraw()


## One 10 ms logic tick plus the view's per-tick bookkeeping.
func step_tick() -> void:
	_snap_prev()
	logic.tick()
	if logic.screen == "game" and not logic.ball.on_paddle:
		_trail.append(Vector2(logic.ball.x + 8, logic.ball.y + 8))
		if _trail.size() > 10:
			_trail.pop_front()
	elif not _trail.is_empty():
		_trail.pop_front()
	_drain()


func _drain() -> void:
	for ev in logic.take_events():
		_on_event(ev)


# ---- input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			return                                # PauseOverlay
		_on_key(event)
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		_point(event.position)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_point(event.position)
			_tap()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_point(event.position)
			_tap()
			get_viewport().set_input_as_handled()


func _on_key(k: InputEventKey) -> void:
	var handled := true
	match k.keycode:
		KEY_LEFT, KEY_A:
			_held_left = k.pressed
			logic.set_held(_held_left, _held_right)
		KEY_RIGHT, KEY_D:
			_held_right = k.pressed
			logic.set_held(_held_left, _held_right)
		KEY_UP, KEY_W, KEY_SPACE:
			if k.pressed and not k.echo:
				_tap()
		KEY_ENTER, KEY_KP_ENTER:
			if k.pressed and not k.echo:
				logic.start()
		KEY_P:
			if k.pressed and not k.echo:
				logic.toggle_pause()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _tap() -> void:
	if logic.screen in ["title", "gameover"]:
		logic.start()
	else:
		logic.try_serve()


## Viewport position -> logical field x for the paddle to chase.
func _point(viewport_pos: Vector2) -> void:
	var stage := (viewport_pos - position) / scale.x
	logic.pointer_x = clampf((stage.x - FIELD_POS.x) / FS, 0.0, Logic.W)


# ---- events and juice ---------------------------------------------------------------

func _on_event(ev: Dictionary) -> void:
	match ev.type:
		&"brick_hit":
			_brick_flash[ev.index] = 1.0
			_burst(ev.pos, Color(1, 1, 1), 5, 90.0, 1.5, 0.3, 0.0)
			_float_text(ev.pos, "+1")
			_shake = maxf(_shake, 0.12)
		&"brick_break":
			_brick_flash.erase(ev.index)
			_burst(ev.pos, SHADE_COLORS[1], 14, 150.0, 3.0, 0.7, 520.0)
			_burst(ev.pos, Color(1, 1, 1), 4, 60.0, 2.0, 0.25, 0.0)
			_float_text(ev.pos, "+1")
			_shake = maxf(_shake, 0.28)
		&"paddle":
			_paddle_squash = 1.0
			_burst(ev.pos + Vector2(0, 8), PADDLE_ACCENT, 5, 80.0, 1.5, 0.3, 200.0)
		&"wall":
			_burst(ev.pos, MUTED, 3, 50.0, 1.2, 0.2, 0.0)
		&"serve":
			_burst(ev.pos + Vector2(0, 8), BALL_GLOW, 6, 70.0, 1.5, 0.3, 0.0)
		&"lost":
			_lake_flash = 1.0
			_shake = 1.0
			_trail.clear()
			_burst(Vector2(ev.pos.x, LAKE_Y), WATER_LIGHT, 18, 140.0, 2.5, 0.8, 420.0, -1.0)
		&"screen":
			_on_screen(ev.screen)
			if ev.screen == "gameover" and logic.new_best:
				_save_best(logic.best)


func _burst(pos: Vector2, color: Color, n: int, speed: float, size: float, life: float,
		grav: float, up := 0.0) -> void:
	for i in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.35, 1.0)
		if up != 0.0:
			v.y = -absf(v.y) - speed * 0.4
		_particles.append({"pos": pos, "vel": v, "life": life, "max": life,
			"color": color, "size": size * randf_range(0.6, 1.2), "grav": grav})
	if _particles.size() > 400:
		_particles = _particles.slice(_particles.size() - 400)


func _float_text(pos: Vector2, text: String) -> void:
	_floaters.append({"pos": pos, "life": 0.6, "text": text})


func _animate(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 3.0)
	_paddle_squash = move_toward(_paddle_squash, 0.0, delta * 6.0)
	_lake_flash = move_toward(_lake_flash, 0.0, delta * 2.0)
	for k in _brick_flash.keys():
		_brick_flash[k] -= delta * 5.0
		if _brick_flash[k] <= 0.0:
			_brick_flash.erase(k)
	for p in _particles:
		p.life -= delta
		p.vel.y += p.grav * delta
		p.pos += p.vel * delta
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos.y -= 30.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	if logic.score != _shown_score:
		_pop_score(_shown_score >= 0 and logic.score > _shown_score)
		_shown_score = logic.score
	_level_label.text = str(logic.current_level)
	_best_label.text = str(maxi(logic.best, logic.score))
	_bricks_label.text = "%d / %d" % [logic.brick_count, logic.bricks.size()]
	_serve_hint.visible = logic.screen == "game" and logic.ball.on_paddle
	_serve_hint.modulate.a = 0.55 + 0.45 * sin(_time * 4.0)
	_retry_hint.visible = logic.can_restart()


func _pop_score(pop: bool) -> void:
	_score_label.text = str(logic.score)
	if not pop:
		return
	_score_label.pivot_offset = _score_label.size * 0.5
	if _score_tween:
		_score_tween.kill()
	_score_label.scale = Vector2(1.3, 1.3)
	_score_label.modulate = GOLD
	_score_tween = create_tween().set_parallel()
	_score_tween.tween_property(_score_label, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_score_tween.tween_property(_score_label, "modulate", Color.WHITE, 0.3)


func _on_screen(screen: String) -> void:
	for key in _cards:
		var card: Control = _cards[key]
		var show: bool = key == screen
		if show and not card.visible:
			card.modulate.a = 0.0
			card.position.y = 30.0
			var tw := create_tween().set_parallel()
			tw.tween_property(card, "position:y", 0.0, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "modulate:a", 1.0, 0.2)
		card.visible = show
	match screen:
		"clear":
			_clear_label.text = "Level %d clear!" % logic.current_level
		"gameover":
			_over_score.text = str(logic.player_score)
			_over_best.text = str(logic.best)
			_over_level.text = str(logic.player_level)
			_new_best.visible = logic.new_best
		"title":
			_title_best.text = "best %d" % logic.best
			_title_best.visible = logic.best > 0
		"game":
			_snap_prev()


# ---- drawing --------------------------------------------------------------------

func _draw() -> void:
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 8.0 * _shake * _shake
	draw_set_transform(shake)
	var m := 400.0
	draw_polygon(PackedVector2Array([Vector2(-m, -m), Vector2(STAGE.x + m, -m),
		Vector2(STAGE.x + m, STAGE.y + m), Vector2(-m, STAGE.y + m)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	draw_style_box(_panel_style, Rect2(28, 100, 184, 600))
	draw_style_box(_panel_style, Rect2(1068, 100, 184, 600))
	_draw_lives(shake)
	# field frame glow
	var frame := Rect2(FIELD_POS, Vector2(Logic.W, Logic.H) * FS)
	for i in 3:
		draw_rect(frame.grow(3 + i * 4), Color(FRAME, 0.10 - i * 0.03), false, 4.0)
	draw_rect(frame.grow(2), FRAME, false, 2.0)
	draw_set_transform(shake + FIELD_POS, 0.0, Vector2(FS, FS))
	_draw_field()
	draw_set_transform(shake)
	for f in _floaters:
		var a: float = clampf(f.life / 0.6, 0.0, 1.0)
		var p: Vector2 = FIELD_POS + f.pos * FS
		draw_string_outline(_font, p + Vector2(-12, 8), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			6, Color(0, 0, 0, 0.6 * a))
		draw_string(_font, p + Vector2(-12, 8), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			Color(GOLD, a))
	draw_set_transform(Vector2.ZERO)


func _alpha() -> float:
	return clampf(_acc_ms / Logic.TICK_MS, 0.0, 1.0)


func _draw_field() -> void:
	var W := float(Logic.W)
	draw_rect(Rect2(0, 0, W, Logic.H), FIELD_BG)
	var gx := 0.0
	while gx <= W:
		draw_line(Vector2(gx, 0), Vector2(gx, LAKE_Y), GRID, 0.5)
		gx += 20.0
	var gy := 0.0
	while gy <= LAKE_Y:
		draw_line(Vector2(0, gy), Vector2(W, gy), GRID, 0.5)
		gy += 20.0
	_draw_bricks()
	for p in _particles:
		var a: float = p.life / p.max
		var s: float = p.size * (0.5 + 0.5 * a)
		draw_rect(Rect2(p.pos - Vector2(s, s) * 0.5, Vector2(s, s)), Color(p.color, a))
	_draw_paddle()
	if logic.screen != "title":
		_draw_ball()
	_draw_lake()


func _draw_bricks() -> void:
	for i in logic.bricks.size():
		var b = logic.bricks[i]
		if not b.solid:
			continue
		var col: Color = SHADE_COLORS[b.shade]
		var r := Rect2(b.x + 1, b.y + 1, b.w - 2, b.h - 2)
		var fl: float = _brick_flash.get(i, 0.0)
		if fl > 0.0:
			r = r.grow(fl * 1.5)
		_brick_style.bg_color = Color(col, 0.12)           # soft glow
		draw_style_box(_brick_style, r.grow(1.5))
		_brick_style.bg_color = col.darkened(0.15)
		draw_style_box(_brick_style, r)
		draw_rect(Rect2(r.position.x + 2, r.position.y + 1.5, r.size.x - 4, 3), col.lightened(0.35))
		draw_rect(Rect2(r.position.x + 2, r.end.y - 3, r.size.x - 4, 1.5), col.darkened(0.45))
		# pips: hits left
		for k in b.shade:
			draw_circle(Vector2(r.get_center().x + (k - (b.shade - 1) * 0.5) * 4.0, r.get_center().y + 1.5),
				0.9, Color(1, 1, 1, 0.55))
		if fl > 0.0:
			_brick_style.bg_color = Color(1, 1, 1, fl * 0.85)
			draw_style_box(_brick_style, r)


func _draw_paddle() -> void:
	var p = logic.paddle
	var x := lerpf(_prev_paddle, p.x, _alpha())
	var sq := _paddle_squash
	var w: float = p.w * (1.0 + 0.10 * sq)
	var h: float = p.h * (1.0 - 0.25 * sq)
	var r := Rect2(x + p.w * 0.5 - w * 0.5, p.y + (p.h - h), w, h)
	_paddle_style.bg_color = Color(PADDLE_ACCENT, 0.10 + 0.25 * sq)
	draw_style_box(_paddle_style, r.grow(3))
	_paddle_style.bg_color = PADDLE.darkened(0.25)
	draw_style_box(_paddle_style, r)
	_paddle_style.bg_color = PADDLE
	draw_style_box(_paddle_style, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.7)))
	draw_rect(Rect2(r.position.x + 6, r.end.y - 4, r.size.x - 12, 2), PADDLE_ACCENT)


func _draw_ball() -> void:
	var b = logic.ball
	var pos := _prev_ball.lerp(Vector2(b.x, b.y), _alpha()) + Vector2(8, 8)
	for i in _trail.size():
		var t := float(i + 1) / (_trail.size() + 1)
		draw_circle(_trail[i], 7.0 * t, Color(BALL_GLOW, 0.25 * t))
	draw_circle(pos, 13.0, Color(BALL_GLOW, 0.10))
	draw_circle(pos, 10.0, Color(BALL_GLOW, 0.18))
	draw_circle(pos, 8.0, BALL)
	draw_circle(pos + Vector2(-2.5, -2.5), 2.6, Color(1, 1, 1, 0.95))
	draw_arc(pos, 7.6, 0.0, TAU, 24, Color(BALL_GLOW, 0.9), 1.0, true)


func _draw_lake() -> void:
	var W := float(Logic.W)
	var col := WATER.lerp(Color(1.0, 0.35, 0.40, 0.85), _lake_flash * 0.7)
	var pts := PackedVector2Array()
	var steps := 40
	for i in steps + 1:
		var x := W * i / steps
		pts.append(Vector2(x, LAKE_Y + sin(x * 0.06 + _time * 3.0) * 1.2))
	var poly := pts.duplicate()
	poly.append(Vector2(W, Logic.H))
	poly.append(Vector2(0, Logic.H))
	draw_colored_polygon(poly, col)
	draw_polyline(pts, Color(WATER_LIGHT, 0.9), 1.0, true)


func _draw_lives(shake: Vector2) -> void:
	for i in Logic.SPARES_START:
		var c := shake + Vector2(70 + i * 50, 228)
		if i < logic.balls_left:
			draw_circle(c, 15.0, Color(BALL_GLOW, 0.15))
			draw_circle(c, 11.0, BALL)
			draw_circle(c + Vector2(-3.5, -3.5), 3.5, Color.WHITE)
		else:
			draw_arc(c, 11.0, 0.0, TAU, 24, Color(MUTED, 0.35), 2.0, true)


# ---- UI ---------------------------------------------------------------------------

func _label(text: String, size: int, color := INK, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.08))
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color, font_size := 28) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = color.lightened(0.15) if state == "hover" else color.darkened(0.15) if state == "pressed" else color
		s.border_color = color.lightened(0.45)
		s.set_border_width_all(2)
		s.set_corner_radius_all(12)
		s.content_margin_left = 32
		s.content_margin_right = 32
		s.content_margin_top = 8
		s.content_margin_bottom = 10
		b.add_theme_stylebox_override(state, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	return b


func _place(c: Control, rect: Rect2) -> Control:
	c.position = rect.position
	c.size = rect.size
	return c


func _card(root: Control, key: String) -> VBoxContainer:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	_place(holder, Rect2(0, 0, STAGE.x, STAGE.y))
	root.add_child(holder)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.06, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(shade, Rect2(FIELD_POS, Vector2(Logic.W, Logic.H) * FS))
	holder.add_child(shade)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(center, Rect2(FIELD_POS, Vector2(Logic.W, Logic.H) * FS))
	holder.add_child(center)
	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.09, 0.20, 0.96)
	s.border_color = FRAME
	s.set_border_width_all(2)
	s.set_corner_radius_all(20)
	s.shadow_color = Color(FRAME, 0.25)
	s.shadow_size = 18
	s.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", s)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	_cards[key] = holder
	return v


func _hud_block(root: Control, x: float, y: float, caption: String) -> Label:
	var cap := _label(caption, 18, MUTED)
	_place(cap, Rect2(x, y, 184, 26))
	root.add_child(cap)
	var val := _label("0", 38, INK)
	_place(val, Rect2(x, y + 24, 184, 50))
	root.add_child(val)
	return val


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(root, Rect2(Vector2.ZERO, STAGE))
	_ui.add_child(root)
	_ui.follow_viewport_enabled = false

	var title := _label("BRICKSLAYER", 26, Color(FRAME.lightened(0.3)))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(title, Rect2(860, 30, 380, 40))
	root.add_child(title)

	_score_label = _label("0", 64, Color.WHITE, 10)
	_place(_score_label, Rect2(STAGE.x * 0.5 - 200, 8, 400, 84))
	root.add_child(_score_label)

	var lives := _label("LIVES", 18, MUTED)
	_place(lives, Rect2(28, 180, 184, 26))
	root.add_child(lives)
	_level_label = _hud_block(root, 28, 290, "LEVEL")
	var keys := _label("<- -> / A D / mouse\nmove\n\n^ / space / click\nserve\n\nP pause\nEsc menu", 16, MUTED)
	_place(keys, Rect2(28, 430, 184, 240))
	root.add_child(keys)
	_best_label = _hud_block(root, 1068, 180, "BEST")
	_bricks_label = _hud_block(root, 1068, 290, "BRICKS")
	_bricks_label.add_theme_font_size_override("font_size", 30)

	_serve_hint = _label("^ / space / click to serve", 26, INK, 6)
	_place(_serve_hint, Rect2(FIELD_POS.x, FIELD_POS.y + 380, Logic.W * FS, 40))
	root.add_child(_serve_hint)

	var tv := _card(root, "title")
	tv.add_child(_label("Brickslayer", 72, Color.WHITE, 12))
	tv.add_child(_label("ENHANCED", 26, GOLD))
	tv.add_child(_label("Break every brick. Each hit scores 1.\nBricks take up to 5 hits; their color shows how many are left.\nYou get 3 spare balls.", 20, MUTED))
	var play := _button("Play", Color(0.85, 0.30, 0.50))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(logic.start)
	tv.add_child(play)
	tv.add_child(_label("or press enter / space", 18, MUTED))
	_title_best = _label("best 0", 22, GOLD)
	tv.add_child(_title_best)

	var pv := _card(root, "pause")
	pv.add_child(_label("Paused", 64, Color.WHITE, 10))
	pv.add_child(_label("press P to resume", 22, MUTED))

	var cv := _card(root, "clear")
	_clear_label = _label("Level 1 clear!", 60, GOLD, 10)
	cv.add_child(_clear_label)
	cv.add_child(_label("get ready...", 22, MUTED))

	var ov := _card(root, "gameover")
	ov.add_child(_label("Game Over", 68, Color.WHITE, 12))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 50)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ov.add_child(grid)
	for caption in ["SCORE", "BEST", "LEVEL"]:
		grid.add_child(_label(caption, 18, MUTED))
	_over_score = _label("0", 48, Color.WHITE)
	_over_best = _label("0", 48, GOLD)
	_over_level = _label("1", 48, Color.WHITE)
	for l in [_over_score, _over_best, _over_level]:
		grid.add_child(l)
	_new_best = _label("New best!", 28, GOLD, 6)
	ov.add_child(_new_best)
	var again := _button("Play again", Color(0.85, 0.30, 0.50))
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func(): logic.start())
	ov.add_child(again)
	_retry_hint = _label("or press enter / space", 18, MUTED)
	ov.add_child(_retry_hint)

	var back := _button("Back to Arcade", Color(0.25, 0.32, 0.65), 18)
	for state in ["normal", "hover", "pressed"]:
		var s: StyleBoxFlat = back.get_theme_stylebox(state)
		s.content_margin_left = 14
		s.content_margin_right = 14
		s.content_margin_top = 6
		s.content_margin_bottom = 8
	back.position = Vector2(14, 12)
	back.pressed.connect(GameRegistry.return_to_arcade)
	root.add_child(back)


func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value("brickslayer", "best", 0))


func _save_best(value: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("brickslayer", "best", value)
	cfg.save(SAVE_PATH)
